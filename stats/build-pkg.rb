#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require 'set'
require "#{LKP_SRC}/lib/common"

class ErrorMessages
  def initialize
    @seqno = ''
    @in_stderr = false
    @error_line = ''
    @error_details = ''
    @error_message = {}
    @error_messages = Hash.new { |h, k| h[k] = Set.new }
  end

  def obtain_error_messages(log_lines)
    log_lines.each do |line|
      next if extract_error_message(line)
      next unless @in_stderr
      next unless @error_message['error_line'] =~ /(error|warning):[^:]/i

      error_id = build_pkg_error_id(@error_message['error_line'])
      @error_messages[error_id] << @error_message['error_line'] + @error_message['error_details']
    end
    return @error_messages
  end

  private

  def extract_error_message(line)
    if line =~ /^ /
      @error_details += line
    else
      update_error_message(line)
      case line
      when /^## ______________([0-9.]+):stderr$/
        @in_stderr = true
        @seqno = $1
        return true

      when /^## ______________#{@seqno}:enderr$/
        @in_stderr = false
        @seqno = ''
        add_error_message
      end
    end
  end

  def update_error_message(line)
    @error_message['error_line'] = @error_line
    @error_message['error_details'] = @error_details
    @error_line = line
    @error_details = ''
  end

  def add_error_message
    return unless @error_message['error_line'] =~ /(error|warning):[^:]/i

    error_id = build_pkg_error_id(@error_message['error_line'])
    @error_messages[error_id] << @error_message['error_line'] + @error_message['error_details']
  end
end

def build_pkg(log_lines)
  message = {}
  ErrorMessages.new.obtain_error_messages(log_lines).each do |k, v|
    message[k] = '1'
    message["#{k}.message"] = v.to_a
  end

  return message
end
