#!/usr/bin/env crystal

require "../../lib/statistics"
require "../../lib/log"

bytes = 0
kbps = [] of Float64 | Int32
throughput = [] of Float64
median = [] of Float64 | Int32
free_secs = [] of Float64
ret = {} of String => Bool
ret["warned"] = false

def add_one_sample(kbps, throughput, median, ret)
  return if kbps.empty?

  throughput << kbps.sum
  kbps.sort!
  count = kbps.size / 2
  median << kbps[count.to_i]
  puts "# #{kbps.size} #{kbps.sum}"
  return unless kbps.size != 1 && (kbps.size & 1) != 0 && !ret["warned"]

  # Log.warn { "stats/vm-scalability: possibly disordered output #{ARGV[0]}"}
  log_warn "stats/vm-scalability: possibly disordered output #{ARGV[0]}"

  ret["warned"] = true
end

while (line = STDIN.gets)
  case line
  when /^\.*(\d+) bytes \/ (\d+) usecs = (\d+) KB.s/
    bytes += $1.to_i
    kbps << $3.to_i
  when /(\d+) bytes \([0-9.]+ .B(?:, [0-9.]+ .iB)?\) copied, ([0-9.]+) s, ([0-9.]+) .B.s/
    bytes += $1.to_i
    kbps << ($1.to_i >> 10) / $2.to_f
  when /(\d+) bytes truncated in ([0-9.]+)-([0-9.]+) seconds/
    bytes += $1.to_i
    kbps << ($1.to_i >> 10) / ($2.to_f - $3.to_f)
  when /\d+ \* \d+ bytes migrated, \d+ usecs, (\d+) MB.s/
    bytes += $1.to_i
    puts "migrate_mbps: " + $1
  when /(\d+) bytes remapped, (\d+) usecs, (\d+) MB.s/
    bytes += $1.to_i
    kbps << $1.to_i / ($2.to_i >> 10)
  when /(\d+) usecs to free memory/
    free_secs << $1.to_i / 1_000_000.0
  when /\.\/case-[a-z-]+/
    add_one_sample(kbps, throughput, median, ret)
    kbps.clear
  end
end

add_one_sample(kbps, throughput, median, ret)
exit if throughput.empty?

# Relative standard deviation
stddev = if throughput.size > 1
           throughput.standard_deviation / throughput.average
         else
           kbps.standard_deviation * kbps.size / kbps.average
         end

median_stddev = if median.size > 1
                  median.standard_deviation / median.average
                else
                  0
                end

printf "throughput: %d\n", throughput.average
if kbps.empty?
  log_error "stats/vm-scalability: incomplete output"
  exit
end
printf "stddev%%:   %g\n", stddev * 100
printf "free_time:  %g\n", free_secs.average unless free_secs.empty?
printf "median: %d\n", median.average
printf "median_stddev%%: %g\n", median_stddev * 100
printf "workload: %.2f\n", bytes.to_f / 1024
