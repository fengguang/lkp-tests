#!/usr/bin/env crystal

while (line = STDIN.gets)
  next unless line =~ /spinlock:\s+\d+\s+(\d+).+\s+(\d+)$/

  puts "threads: #{$1}"
  puts "score: #{$2}"
end
