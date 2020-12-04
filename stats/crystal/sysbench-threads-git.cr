#!/usr/bin/env crystal

# General statistics:
#     total time:                          0.2671s
#     total number of events:              10000
#     total time taken by event execution: 0.3971s
#     response time:
#           min:                           0.04ms

while (line = STDIN.gets)
  next unless line =~ /^\s+total\stime:\s+(\S+)/

  puts "total time: #{$1}"
end
