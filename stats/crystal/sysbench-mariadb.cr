#!/usr/bin/env crystal

while (line = STDIN.gets)
  if line =~ /transactions:\s+(\d+)/
    puts "transactions: #{$1}"
  end
  if line =~ /95th percentile:\s+(\S+)/
    puts "95th_percentile: #{$1}"
  end
end
