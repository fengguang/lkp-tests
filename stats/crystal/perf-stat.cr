#!/usr/bin/env crystal

global_results_sum = Hash(String, Int32).new(0)
global_results_nr = Hash(String, Int32).new(0)
global_interval_results_sum = Hash(String, Int32).new(0)
global_interval_results_nr = Hash(String, Int32).new(0)
global_interval_nr = 0
global_run_time = 0

global_stats_begin_time = ENV["stats_part_begin"].to_f
global_stats_end_time = ENV["stats_part_end"].to_f

global_latency_prev = Hash(String, Int32).new(0)

def calc_addon_keys(results_sum, results_nr, interval, interval_nr, prefix)
  results_sum.each do |key, value|
    case key
    when /(.*)-misses/
      stem = $1
      ["s", "-references", "-instructions"].each do |pfx|
        avalue = results_sum[stem + pfx]
        next if avalue.zero?

        total = if pfx == "s"
                  avalue + value
                else
                  avalue
                end
        puts "#{prefix}#{stem}-miss-rate%: #{value * 100.0 / total}"
        break
      end
      next if value.zero?
      if key =~ /(.*)iTLB-load-misses/
        stem = $1
        instructions = results_sum[stem + "instructions"]
        puts "#{prefix}#{stem}instructions-per-iTLB-miss: #{instructions / value}" unless instructions.zero?
      elsif key =~ /(.*)cache-misses/
        stem = $1
        cycles = results_sum[stem + "cpu-cycles"]
        puts "#{prefix}#{stem}cycles-between-cache-misses: #{cycles / value}" unless cycles.zero?
      end
    when /(.*)cache-references/
      stem = $1
      instructions = results_sum[stem + "instructions"]
      puts "#{prefix}#{stem}MPKI: #{value / instructions * 1000}" unless instructions.zero?
    when /(.*)UNC_M_(.*)_INSERTS/
      stem1 = $1
      stem2 = global_2
      stem = "#{stem1}UNC_M_#{stem2}"
      occupancy_key = stem1 + "UNC_M_" + stem2 + "_OCCUPANCY"
      occupancy = results_sum[occupancy_key]
      ticks_key = stem1 + "UNC_M_CLOCKTICKS"
      ticks_sum = results_sum[ticks_key]
      ticks_nr = results_nr[ticks_key].to_f
      if results_sum.has_key?(occupancy_key) && ticks_sum != 0
        # Need to deal with _INSERTSS == 0
        latency_key = "#{prefix}#{stem}_latency_ns"
        latency = if value != 0
                    occupancy / value / (ticks_sum / (ticks_nr / interval_nr)) * 1e+9 * interval
                  else
                    global_latency_prev[latency_key]
                  end
        global_latency_prev[latency_key] = latency
        puts "#{latency_key}: #{latency}"
      end
      puts "#{prefix}#{stem}_throughput_MBps: #{value.to_f * 64 / 1024 / 1024 / interval}"
    when /(.*)cpu-cycles/
      stem = $1
      instructions = results_sum[stem + "instructions"]
      unless instructions.zero?
        puts "#{prefix}#{stem}ipc: #{instructions / value}"
        puts "#{prefix}#{stem}cpi: #{value / instructions}"
      end
    end
  end
end

def output_interval(prev_time, time)
  return if global_interval_results_sum.empty?

  interval = time - prev_time
  puts "time: #{time}"
  global_interval_results_sum.each do |key, value|
    puts "i.#{key}: #{value / interval}"
  end
  calc_addon_keys(global_interval_results_sum, global_interval_results_nr,
                  interval, 1, "i.")

  ignore = false
  if time <= global_stats_begin_time
    ignore = true
  elsif prev_time <= global_stats_begin_time
    # update global_stats_begin_time to real start time
    global_stats_begin_time = prev_time
  end

  if !ignore && global_stats_end_time != 0 && time > global_stats_end_time
    global_stats_end_time = prev_time if prev_time <= global_stats_end_time
    ignore = true
  end

  unless ignore
    global_interval_results_sum.each do |key, value|
      global_results_sum[key] += value
      global_results_nr[key] += global_interval_results_nr[key]
    end
    global_interval_nr += 1
  end

  global_interval_results_sum.clear
  global_interval_results_nr.clear
end

# Example output
#    290.690747746 777209  mem_load_uops_l3_miss_retired_remote_dram 89128748143 100.00
#    324.224668698 7928832 Bytes llc_misses.mem_read 8005538025 100.00

#    2.003151490 S0 8 321055743  cpu-cycles 8012766737 100.00
#    2.003151490 S0 8 161761287  instructions 8011773256 100.00 0.47 insn per cycle
#    3.004126313 S0 8 319801680  cpu-cycles 8006470194 100.00
#    3.004126313 S0 8 170196182  instructions 8007548409 100.00 0.50 insn per cycle

def parse
  prev_prev_time = 0
  prev_time = 0
  time = 0

  STDIN.each_line do |line|
    next unless line =~ /^\s*\d+\.\d+\s+/

    stime, fields = line.split

    prev_time = time
    time = stime.to_f
    # time different > 10ms, new output
    if time - prev_time > 0.01
      output_interval(prev_prev_time, prev_time)
      prev_prev_time = prev_time
    end
    socket = nil
    unit = nil
    socket_key = nil

    # per-socket mode
    #    S0 8 321055743  cpu-cycles 8012766737 100.00
    if fields[0][0] == "S"
      socket = fields[0]
      fields.delete_at 1
      fields.delete_at 0
    end

    # for unit
    # 7928832 Bytes llc_misses.mem_read 8005538025 100.00
    if fields[1] == "Bytes"
      unit = fields[1]
      fields.delete_at 1
    end

    # 777209 mem_load_uops_l3_miss_retired_remote_dram 89128748143 100.00
    value, key = fields
    value = value.to_f

    i_imc = key.index "_IMC"
    key = key[0, i_imc] if i_imc

    key = "#{key}_#{unit}" if unit
    socket_key = "#{socket}.#{key}" if socket

    global_interval_results_sum[key] += value
    global_interval_results_nr[key] += 1
    if socket_key
      global_interval_results_sum[socket_key] += value
      global_interval_results_nr[socket_key] += 1
    end
  end

  # total time
  end_time = global_stats_end_time == 0 ? prev_time : global_stats_end_time
  global_run_time = end_time - global_stats_begin_time

  # skip the last record, because the interval hasn't run out
end

parse

global_results_sum.each do |key, value|
  # output per-second value
  puts "ps.#{key}: #{value / global_run_time}"
end

instructions = global_results_sum["instructions"]
unless instructions.zero?
  # to calc path-length
  puts "total.instructions: #{instructions}"
end

calc_addon_keys(global_results_sum,
global_results_nr,
global_run_time,
global_interval_nr, "overall.")
