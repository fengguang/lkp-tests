#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']

def puts_err(*messages)
  $stderr.puts "#{File.basename $PROGRAM_NAME}: #{messages.join ' '}"
end

def dump_exception(e, _binding = nil)
  $stderr.puts e.message
  $stderr.puts e.backtrace.join "\n"
end
