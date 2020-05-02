#!/usr/bin/env crystal
# example input:
# =========================================================================
# Type         Ops/sec     Hits/sec   Misses/sec      Latency       KB/sec
# -------------------------------------------------------------------------
# Sets         1455.72          ---          ---      0.42200      1522.73
# Gets         5822.89       867.78      4955.10      0.40700      1088.00
# Waits           0.00          ---          ---      0.00000          ---
# Totals       7278.61       867.78      4955.10      0.41000      2610.72
# Request Latency Distribution
# Type     <= msec         Percent
#------------------------------------------------------------------------
# SET       0.260        87.07
# SET       0.270        89.46
# SET       0.280        92.75
# SET       0.290        95.86
# SET       0.300        97.88
# SET       0.310        98.79
# SET       0.320        99.13
# SET       0.330        99.28
# SET       0.340        99.40
# SET       0.350        99.51
# SET       0.360        99.62
# GET       0.250        85.06
# GET       0.260        87.07
# GET       0.270        89.46
# GET       0.280        92.75
# GET       0.290        95.86
# GET       0.300        97.88
# GET       0.310        98.79
# GET       0.320        99.13
# GET       0.330        99.28
# GET       0.340        99.40

LKP_SRC ||= ENV["LKP_SRC"] || File.dirname(__DIR__)

require "#{LKP_SRC}/lib/array_ext"

$histo_sets_sum = Array.new(6, 0)
$histo_sets_num = Array.new(6, 0)
$histo_gets_sum = Array.new(6, 0)
$histo_gets_num = Array.new(6, 0)
$histo_waits_sum = Array.new(6, 0)
$histo_waits_num = Array.new(6, 0)
$histo_totals_sum = Array.new(6, 0)
$histo_totals_num = Array.new(6, 0)
set_latencies = []
get_latencies = []
proc_set_latencies = []
proc_get_latencies = []
PERCENTILE_STRS = ["90", "95", "99", "99.9"].freeze
PERCENTILES = PERCENTILE_STRS.map(&.to_f)

def extract_memtier(line, histo_sum, histo_num)
  data = line.split
  (1..data.size - 1).each do |i|
    histo_sum[i] += data[i].to_f
    histo_num[i] += 1
  end
end

def memtier(line)
  case line
  when /^preload duration: (\d+\.\d+)$/
    puts "preload_duration: #{$1}"
  end
end

while (line = STDIN.gets)
  if line =~ /^Sets/
    extract_memtier(line, $histo_sets_sum, $histo_sets_num)
  elsif line =~ /^Gets/
    extract_memtier(line, $histo_gets_sum, $histo_gets_num)
  elsif line =~ /^Waits/
    extract_memtier(line, $histo_waits_sum, $histo_waits_num)
  elsif line =~ /^Totals/
    extract_memtier(line, $histo_totals_sum, $histo_totals_num)
  elsif line =~ /^Request Latency Distribution/
    proc_set_latencies = []
    proc_set_latencies = []
  elsif line =~ /^SET/
    is_set = true
    data = line.split
    s_10us = (data[1].to_f * 100).to_i
    proc_set_latencies[s_10us] = data[2].to_f
  elsif line =~ /^GET/
    is_set = false
    data = line.split
    s_10us = (data[1].to_f * 100).to_i
    proc_get_latencies[s_10us] = data[2].to_f
  elsif line =~ /^---$/
    if is_set
      set_latencies << proc_set_latencies
    else
      get_latencies << proc_get_latencies
    end
  else
    memtier(line)
  end
end

def gen_output_sum(type, histo_sum)
  puts "total_#{type}_ops/s: #{histo_sum[1]}"
  puts "total_#{type}_hits/s: #{histo_sum[2]}"
  puts "total_#{type}_misses/s: #{histo_sum[3]}"
  puts "total_#{type}_latency_ms: #{histo_sum[4]}"
  puts "total_#{type}_kb/s: #{histo_sum[5]}"
end

def gen_output_avg(type, histo_sum, histo_num)
  avg_tmp = histo_sum[1] / histo_num[1]
  puts "avg_#{type}_ops/s: #{avg_tmp}"
  avg_tmp = histo_sum[2] / histo_num[2]
  puts "avg_#{type}_hits/s: #{avg_tmp}"
  avg_tmp = histo_sum[3] / histo_num[3]
  puts "avg_#{type}_misses/s: #{avg_tmp}"
  avg_tmp = histo_sum[4] / histo_num[4]
  puts "avg_#{type}_latency_ms: #{avg_tmp}"
  avg_tmp = histo_sum[5] / histo_num[5]
  puts "avg_#{type}_kb/s: #{avg_tmp}"
end

def gen_output_miss_rate(type, histo_sum, histo_num)
  avg_hits = histo_sum[2] / histo_num[2]
  avg_misses = histo_sum[3] / histo_num[3]
  avg_total = avg_hits + avg_misses
  return unless avg_total != 0

  miss_rate = 100 * avg_misses / avg_total
  puts "#{type}_miss_rate_%: #{miss_rate}"
end

gen_output_sum("sets", $histo_sets_sum)
gen_output_sum("gets", $histo_gets_sum)
gen_output_sum("waits", $histo_waits_sum)
gen_output_sum("totals", $histo_totals_sum)
gen_output_avg("sets", $histo_sets_sum, $histo_sets_num)
gen_output_avg("gets", $histo_gets_sum, $histo_gets_num)
gen_output_miss_rate("gets", $histo_gets_sum, $histo_gets_num)
gen_output_avg("waits", $histo_waits_sum, $histo_waits_num)
gen_output_avg("totals", $histo_totals_sum, $histo_totals_num)

def normalize_latencies(latencies)
  maxcol = latencies.map(&.size).max
  latencies.each do |proc_latencies|
    prev = 0
    (0...maxcol).map do |i|
      percent = proc_latencies[i]
      percent ||= prev
      prev = percent
      proc_latencies[i] = percent
    end
  end
end

def show_latencies(latencies, name)
  pi = 0
  latencies.transpose.each_with_index do |ps, i|
    sum = ps.sum
    next unless sum != 0

    avg = sum.to_f / ps.size
    while pi < PERCENTILES.size && avg > PERCENTILES[pi]
      i_ms = i.to_f / 100
      puts "#{name}_latency_#{PERCENTILE_STRS[pi]}%_ms: #{i_ms}"
      pi += 1
    end
    break if avg > PERCENTILES[-1]
  end
end

normalize_latencies(set_latencies)
normalize_latencies(get_latencies)

show_latencies(set_latencies, "set")
show_latencies(get_latencies, "get")
