#!/usr/bin/env crystal

results_total = Hash(String, Array(Float64)).new

def add_result(results, key, val)
  results[key] << val
end

STDIN.each_line do |line|
  case line
  when /OVERALL\W, RunTime.ms., (\d+)$/
    add_result(results_total, "runtime", $1.to_f)
  when /OVERALL\W, Throughput.ops.sec., (\d+\.\d+)$/
    add_result(results_total, "throughput_ops/s", $1.to_f)
  when /TOTAL_GCS_G1_Young_Generation\W, Count, (\d+)$/
    add_result(results_total, "gcs_g1", $1.to_f)
  when /TOTAL_GC_TIME_G1_Young_Generation\W, Time.ms., (\d+)$/
    add_result(results_total, "gc_time_g1", $1.to_f)
  when /TOTAL_GC_TIME_%_G1_Young_Generation\W, Time.%., (\d+\.\d+)$/
    add_result(results_total, "gc_time_%", $1.to_f)
  when /TOTAL_GCS_G1_Old_Generation\W, Count, (\d+)$/
    add_result(results_total, "gcs_g1_old", $1.to_f)
  when /TOTAL_GC_TIME_G1_Old_Generation\W, Time.ms., (\d+)$/
    add_result(results_total, "gc_time_g1_old", $1.to_f)
  when /TOTAL_GC_TIME_%_G1_Old_Generation\W, Time.%., (\d+\.\d+)$/
    add_result(results_total, "gc_time_%_old", $1.to_f)
  when /TOTAL_GCs\W, Count, (\d+)$/
    add_result(results_total, "total_gcs", $1.to_f)
  when /TOTAL_GC_TIME\W, Time.ms., (\d+)$/
    add_result(results_total, "total_gc_time", $1.to_f)
  when /TOTAL_GC_TIME_%\W, Time.%., (\d+\.\d+)$/
    add_result(results_total, "total_gc_time_%", $1.to_f)
  when /READ\W, Operations, (\d+)$/
    add_result(results_total, "read_operations", $1.to_f)
  when /READ\W, AverageLatency.us., (\d+\.\d+)$/
    add_result(results_total, "read_averagelatency", $1.to_f)
  when /READ\W, MinLatency.us., (\d+)$/
    add_result(results_total, "read_minlatency", $1.to_f)
  when /READ\W, MaxLatency.us., (\d+)$/
    add_result(results_total, "read_maxlatency", $1.to_f)
  when /READ\W, 95thPercentileLatency.us., (\d+)$/
    add_result(results_total, "read_95%latency", $1.to_f)
  when /READ\W, 99thPercentileLatency.us., (\d+)$/
    add_result(results_total, "read_99%latency", $1.to_f)
  when /READ\W, Return=OK, (\d+)$/
    add_result(results_total, "read_return_ok", $1.to_f)
  when /READ\W, Return=NOT_FOUND, (\d+)$/
    add_result(results_total, "read_return_notfound", $1.to_f)
  when /CLEANUP\W, Operations, (\d+)$/
    add_result(results_total, "cleanup_operations", $1.to_f)
  when /CLEANUP\W, AverageLatency.us., (\d+\.\d+)$/
    add_result(results_total, "cleanup_averagelatency", $1.to_f)
  when /CLEANUP\W, MinLatency.us., (\d+)$/
    add_result(results_total, "cleanup_minlatency", $1.to_f)
  when /CLEANUP\W, MaxLatency.us., (\d+)$/
    add_result(results_total, "cleanup_maxlatency", $1.to_f)
  when /CLEANUP\W, 95thPercentileLatency.us., (\d+)$/
    add_result(results_total, "cleanup_95%latency", $1.to_f)
  when /CLEANUP\W, 99thPercentileLatency.us., (\d+)$/
    add_result(results_total, "cleanup_99%latency", $1.to_f)
  when /READ-FAILED\W, Operations, (\d+)$/
    add_result(results_total, "read_failed_operations", $1.to_f)
  when /READ-FAILED\W, AverageLatency.us., (\d+\.\d+)$/
    add_result(results_total, "read_failed_averagelatency", $1.to_f)
  when /READ-FAILED\W, MinLatency.us., (\d+)$/
    add_result(results_total, "read_failed_minlatency", $1.to_f)
  when /READ-FAILED\W, MaxLatency.us., (\d+)$/
    add_result(results_total, "read_failed_maxlatency", $1.to_f)
  when /READ-FAILED\W, 95thPercentileLatency.us., (\d+)$/
    add_result(results_total, "read_failed_95%latency", $1.to_f)
  when /READ-FAILED\W, 99thPercentileLatency.us., (\d+)$/
    add_result(results_total, "read_failed_99%latency", $1.to_f)
  when /INSERT\W, Operations, (\d+)$/
    add_result(results_total, "insert_operations", $1.to_f)
  when /INSERT\W, AverageLatency.us., (\d+\.\d+)$/
    add_result(results_total, "insert_averagelatency", $1.to_f)
  when /INSERT\W, MinLatency.us., (\d+)$/
    add_result(results_total, "insert_minlatency", $1.to_f)
  when /INSERT\W, MaxLatency.us., (\d+)$/
    add_result(results_total, "insert_maxlatency", $1.to_f)
  when /INSERT\W, 95thPercentileLatency.us., (\d+)$/
    add_result(results_total, "insert_95%latency", $1.to_f)
  when /INSERT\W, 99thPercentileLatency.us., (\d+)$/
    add_result(results_total, "insert_99%latency", $1.to_f)
  when /INSERT\W, Return=OK, (\d+)$/
    add_result(results_total, "insert_return_ok", $1.to_f)
  when /INSERT\W, Return=ERROR, (\d+)$/
    add_result(results_total, "insert_return_error", $1.to_f)
  when /INSERT-FAILED\W, Operations, (\d+)$/
    add_result(results_total, "insert_failed_operations", $1.to_f)
    puts "insert_failed_operations: #{$1}"
  when /INSERT-FAILED\W, AverageLatency.us., (\d+\.\d+)$/
    add_result(results_total, "insert_failed_averagelatency", $1.to_f)
  when /INSERT-FAILED\W, MinLatency.us., (\d+)$/
    add_result(results_total, "insert_failed_minlatency", $1.to_f)
    puts "insert_failed_minlatency: #{$1}"
  when /INSERT-FAILED\W, MaxLatency.us., (\d+)$/
    add_result(results_total, "insert_failed_maxlatency", $1.to_f)
  when /INSERT-FAILED\W, 95thPercentileLatency.us., (\d+)$/
    add_result(results_total, "insert_failed_95%latency", $1.to_f)
  when /INSERT-FAILED\W, 99thPercentileLatency.us., (\d+)$/
    add_result(results_total, "insert_failed_99%latency", $1.to_f)
  when /^preload duration: (\d+\.\d+)$/
    puts "preload_duration: #{$1}"
  end
end

results_total.each do |key, vals|
  puts "total_#{key}: #{vals.sum}"
end

results_total.each do |key, vals|
  puts "avg_#{key}: #{vals.sum / vals.size}"
end
