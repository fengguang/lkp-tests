#!/usr/bin/env crystal

$stdin.each_line do |line|
  if line =~ /Averaged ([\d.]+) operations\/sec \(\+- ([\d.]+)%\)/
    puts "ops/s: #{$1}"
    puts "stddev%: #{$2}"
  end
end
