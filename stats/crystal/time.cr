#!/usr/bin/env crystal

while (line = STDIN.gets)
  next if line.index("Command being timed: ")

  key, val = line.split ": "

  # skip the first line to avoid empty val.
  # Command exited with non-zero status 2
  #   Command being timed: "/lkp/wfg/src/tests/kernel-selftests"
  #   User time (seconds): 13.70
  #   ...
  next unless val

  key = key.gsub(/^\s+/, "").gsub(/ \([^)]+\)/, "").gsub(/\s+/, "_").downcase
  case key
  when "elapsed_time"
    times = val.split ":"
      val = times.each_with_index do |tt,t|
	    tt * 60 + t.to_f.to_s
    end
  when "percent_of_cpu_this_job_got"
    val = val.chomp("%")
    val = "0" if val == "?"
  end
  puts "#{key}: #{val}"
end
