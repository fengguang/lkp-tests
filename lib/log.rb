#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']

require 'logger'

log_formatter = proc do |severity, datetime, _progname, msg|
  msg = if msg.is_a? Exception
          ["#{msg.backtrace.first}: #{msg.message.split("\n").first} (#{msg.class.name})", msg.backtrace[1..-1].map { |m| "\tfrom #{m}" }].flatten
        else
          msg.to_s.split("\n")
        end

  msg.map { |m| "#{datetime} #{severity} -- #{m}\n" }.join
end

$log = Logger.new($stdout)
$log.formatter = log_formatter

$log_error = Logger.new($stderr)
$log_error.formatter = log_formatter

# below methods are available
#   - log_debug
#   - log_info
%w(debug info).each do |severity|
  define_method("log_#{severity}") do |*args, &block|
    $log.send(severity, *args, &block)
  end
end

alias log log_info

# below methods are available
#   - log_warn
#   - log_error
%w(warn error).each do |severity|
  define_method("log_#{severity}") do |*args, &block|
    $log_error.send(severity, *args, &block)
  end
end

def log_verbose(*args, &block)
  return unless ENV['LKP_VERBOSE']

  $log.debug(*args, &block)
end

def log_exception(e, _binding = nil)
  log_error e
end
