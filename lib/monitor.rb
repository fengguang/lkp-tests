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

  def run
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
        puts
        if data['log']
          puts JSON.parse(data['log'])
        else
          puts data
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
