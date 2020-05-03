#!/usr/bin/env crystal


require "../../lib/log"

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
