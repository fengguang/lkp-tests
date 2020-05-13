#!/usr/bin/env crystal


require "../../lib/statistics"

linkbench = {} of String => String

STDIN.each_line do |line|
  case line
  when /\[main\]: (.*) count = (\d+)(.*)max = (\d+).(\d+)ms(.*)mean = (\d+).(\d+)ms/
    linkbench[$1 + ".count"] = $2
    linkbench[$1 + ".max"] = $4 + "." + $5
    linkbench[$1 + ".mean"] = $7 + "." + $8
  when /\[main\]: REQUEST PHASE COMPLETED. (\d+) requests done in (\d+) seconds. Requests\/second = (\d+)/
    puts "workload: " + $1
    puts "duration: " + $2
    puts "requests/s: " + $3
  end
end

linkbench.each do |k, v|
  puts k + ": " + v
end
