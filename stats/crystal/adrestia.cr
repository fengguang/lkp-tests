#!/usr/bin/env crystal

STDIN.each_line do |line|
  case line
  when /wakeup cost \(single/
    puts "wakeup_cost_single_us: " + line.split[3].gsub(/us/, "")
  when /wakeup cost \(periodic/
    puts "wakeup_cost_periodic_us: " + line.split[4].gsub(/us/, "")
  end
end
