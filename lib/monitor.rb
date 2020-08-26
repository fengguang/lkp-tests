#!/usr/bin/env ruby
# frozen_string_literal: true

LKP_SRC ||= env['LKP_SRC'] || File.dirname(__dir__)

require "#{LKP_SRC}/lib/hash"

require 'faye/websocket'
require 'eventmachine'
require 'json'

class Monitor
  attr_accessor :url, :query, :overrides

  def initialize(url = '', overrides = {}, query = {})
    @url = url
    @query = query
    @overrides = overrides
  end

  def merge_overrides
    return if @overrides.empty?

    revise_hash(@query, @overrides, true)
  end

  def field_check
    raise 'url can\'t be empty' if @url.empty?
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

  def run(type = 'output')
    merge_overrides
    field_check
    query = @query.to_json
    puts "query=>#{query}"

    EM.run do
      ws = Faye::WebSocket::Client.new(@url)

      ws.on :open do |_event|
        puts "connect to #{@url}"
        ws.send(query)
      end

      ws.on :message do |event|
        data = JSON.parse(event.data)

        case type
        when 'output'
          output(data)
        when 'connect'
          connect(data, ws)
        else
          raise "Invalid run type: #{type}"
        end
      end

      ws.on :close do |event|
        puts "connection closed: #{event.reason}"
      end
    end
  end

  def []=(key, value)
    @query[key] = value
  end
end
