#!/usr/bin/env ruby
# frozen_string_literal: true

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require "#{LKP_SRC}/lib/hash"
require "#{LKP_SRC}/lib/yaml"

require 'faye/websocket'
require 'eventmachine'
require 'json'

class Monitor
  attr_accessor :monitor_url, :query, :overrides

  def initialize(monitor_url = '', overrides = {}, query = {})
    @monitor_url = monitor_url
    @query = query
    @overrides = overrides
    @defaults = {}
    # exit_status_code: how to exit EM.run
    # 0 means normal exit
    # 1 means timeout exit
    @exit_status_code = 0
    load_default
  end

  def load_default
    Dir.glob(['/etc/crystal-ci/monitor/*.yaml',
              "#{ENV['HOME']}/.config/crystal-ci/monitor/*.yaml"]).each do |file|
      next unless File.exist? file
      next if File.zero? file

      defaults = load_yaml(file)
      next unless defaults.is_a?(Hash)
      next if defaults.empty?

      revise_hash(@defaults, defaults, true)
    end

    @monitor_url = @defaults['monitor_url'] || 'ws://localhost:11310/filter'
  end

  def merge_overrides
    return if @overrides.empty?

    revise_hash(@query, @overrides, true)
  end

  def field_check
    raise 'monitor_url can\'t be empty' if @monitor_url.empty?
    raise 'query can\'t be empty' if @query.empty?
    raise 'query must be Hash' if @query.class != Hash
  end

  def output(data)
    data = JSON.parse(data['log']) if data['log']
    puts data
    return data
  end

  def connect(data, web_socket)
    data = output(data)
    return unless data['ip']

    web_socket.close
    exec "ssh-keygen -R #{data['ip']};
    ssh root@#{data['ip']} -o StrictHostKeyChecking=no"
  end

  def stop_em(web_socket)
    web_socket.close
    EM.stop
  end

  def run(type = 'output', close_time = nil)
    merge_overrides
    field_check
    query = @query.to_json
    puts "query=>#{query}"

    EM.run do
      ws = Faye::WebSocket::Client.new(@monitor_url)

      if close_time
        EM.add_timer(close_time) do
          @exit_status_code = 1
          stop_em(ws)
        end
      end

      ws.on :open do |_event|
        puts "connect to #{@monitor_url}"
        ws.send(query)
      end

      ws.on :message do |event|
        data = JSON.parse(event.data)

        case type
        when 'output'
          output(data)
        when 'connect'
          connect(data, ws)
        when 'stop'
          stop_em(ws)
        else
          raise "Invalid run type: #{type}"
        end
      end

      ws.on :close do |event|
        puts "connection closed: #{event.reason}"
      end
    end
    return @exit_status_code
  end

  def []=(key, value)
    @query[key] = value
  end
end
