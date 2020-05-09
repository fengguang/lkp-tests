#!/usr/bin/env crystal

time = [] of Float64
counts = {} of Int32=>Int32

STDIN.each_line do |line|
  case line
  when /^time: (.*)/
    time << $1.to_f
  when /^(\d+.\d+) Joules power\/(.*)\//
    counts[$2.to_i] = $1.to_i
  end
end

counts.each do |k, v|
  # Joules to watts calculation formula: P(W) = E(J)/t(s)
  # To convert the raw count in Watt: W = C * 0.23 / (1e9 * time)
  watt = v.to_f * 0.23 / (1e9 * (time[1].to_f - time[0].to_f))
  puts "#{k}: #{watt}"
end
