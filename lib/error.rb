#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']

def dump_exception(e, _binding = nil)
  $stderr.puts e.message
  $stderr.puts e.backtrace.join "\n"
end
