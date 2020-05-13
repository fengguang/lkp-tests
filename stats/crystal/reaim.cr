#!/usr/bin/env crystal

# reaim.workload is defined as the total number of jobs for all
# processes/threads

require "../../lib/statistics"

keys = %w(parent_time child_systime child_utime jobs_per_min
          jobs_per_min_child std_dev_time std_dev_percent jti)

results = {} of String => Array(Float64)
jobs = 0
workload = 0
while (line = STDIN.gets)
  case line
  when /^\S+ \S+ .\/reaim\s+-s(\d+)\s+-e(\d+)\s+-i(\d+).*-r(\d+).*-j(\d+)$/
    ($1.to_i..$2.to_i).step($3.to_i) do |v|
      jobs += v * $5.to_f
    end
    jobs *= $4.to_f
    workload += jobs
    jobs = 0
  when /^[ \d.]+$/
    data = line.split
    data[1..-1].each_with_index do |v, i|
      results[keys[i]] ||= [] of Float64
      results[keys[i]] << v.to_f
    end
  end
end

results.each { |k, v| puts "#{k}: #{v.average}" }

puts "max_jobs_per_min: #{results["jobs_per_min"].max}" if results["jobs_per_min"]
puts "workload: #{workload}"
