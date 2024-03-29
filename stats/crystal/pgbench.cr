#!/usr/bin/env crystal

while (line = STDIN.gets)
  case line
  when /number of transactions actually processed: (\d+)/
    puts "transactions: #{$1}"
  when /latency average = ([0-9.]+) (us|ms)/
    latency = $1.to_f
    latency /= 1000 if $2 == "us"
    puts "latency_ms: #{latency}"
  when /tps = ([0-9.]+) \(including connections establishing\)/
    puts "tps: #{$1}"
  when /tps = ([0-9.]+) \(excluding connections establishing\)/
    puts "tps_exclude_connect: #{$1}"
  end
end
