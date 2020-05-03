#!/usr/bin/env crystal

while (line = STDIN.gets)
  case line
  when /^#\(\*\*\)/
    _a, _b, _c, throughput, rtt, jitter = line.split
    puts "throughput: " + throughput
    puts "RTT: " + rtt
    puts "jitter: " + jitter
  end
end
