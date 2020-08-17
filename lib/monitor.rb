#!/usr/bin/env ruby
# frozen_string_literal: true

LKP_SRC ||= env['LKP_SRC'] || File.dirname(__dir__)

require "#{LKP_SRC}/lib/hash"

require 'faye/websocket'
require 'eventmachine'
require 'json'

class Monitor
  attr_accessor :url
  attr_accessor :query
  attr_accessor :overrides

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
    if @url.empty?
      raise 'url can\'t be empty'
    end
    if @query.empty?
      raise 'query can\'t be empty'
    end
    if @query.class != Hash
      raise 'query must be Hash'
    end
  end

  def run
    merge_overrides
    field_check
    query = @query.to_json

    EM.run {
      ws = Faye::WebSocket::Client.new(@url)

      ws.on :open do |event|
        ws.send(query)
      end

      ws.on :message do |event|
        puts event.data
      end

      ws.on :close do |event|
        puts "connection closed: #{event.reason}"
      end
    }
  end

  def []=(k, v)
    @query[k] = v
  end

end
