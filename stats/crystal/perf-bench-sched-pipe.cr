#!/usr/bin/env crystal

while (line = STDIN.gets)
  puts "ops_per_sec: #{$1}" if line =~ /(\d+) ops\/sec/
end
