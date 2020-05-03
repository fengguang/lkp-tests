#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require "#{LKP_SRC}/lib/log"

while (line = STDIN.gets)
  case line
  when /^(.*): +(\d+) kB$/,
       /^(.*): +(\d+) KiB$/,
       /^(.*): +(\d+)$/
    puts $1 + ": " + $2
  else
    log_error "malformed meminfo line: #{line}"
  end
end
