#!/usr/bin/env crystal
# Throughput 51.9127 MB/sec  16 clients  16 procs  max_latency=969.602 ms

STDIN.each_line do |line|
  case line
  when /^Throughput/
    throughput, clients, _procs, _max_latency = line.tr("a-zA-Z_=/", "").split
    puts "throughput-#{clients}: #{throughput}"
    puts ""
  end
end
