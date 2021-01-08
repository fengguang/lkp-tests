#!/usr/bin/env crystal

require "../../lib/statistics"

STDIN.each_line do |line|
  case line
  when /Elapsed Time/
    puts "elapsed_time: " + line.split[2]
    puts "elapsed_time_stddev: " + line.split[3].gsub(/[()]/, "")
  when /User Time/
    puts "user_time: " + line.split[2]
    puts "user_time_stddev: " + line.split[3].gsub(/[()]/, "")
  when /System Time/
    puts "system_time: " + line.split[2]
    puts "system_time_stddev: " + line.split[3].gsub(/[()]/, "")
  when /Percent CPU/
    puts "percent_cpu: " + line.split[2]
    puts "percent_cpu_stddev: " + line.split[3].gsub(/[()]/, "")
  when /Context Switches/
    puts "context_switches: " + line.split[2]
    puts "context_switches_stddev: " + line.split[3].gsub(/[()]/, "")
  when /Sleeps/
    puts "sleeps: " + line.split[1]
    puts "sleeps_stddev: " + line.split[2].gsub(/[()]/, "")
  end
end
