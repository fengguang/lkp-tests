#!/usr/bin/env crystal

#example input:
# Hyper-Threading IS enabled.
# numa01
# 181.85
# numa01_HARD_BIND
# 76.25
# numa01_INVERSE_BIND
# 152.92
# numa01_THREAD_ALLOC
# 95.86
# numa01_THREAD_ALLOC_HARD_BIND
# 65.29
# numa01_THREAD_ALLOC_INVERSE_BIND
# 246.51
# numa02
# 14.31
# numa02_HARD_BIND
# 8.35
# numa02_INVERSE_BIND
# 23.56
# numa02_SMT
# 16.26
# numa02_SMT_HARD_BIND
# 8.27
# numa02_SMT_INVERSE_BIND
# 22.31

results = Hash(String, Float64).new
output = false
key = "" 
#$stdin.each do |line|
STDIN.each_line do |line|
  line = line.strip()
  case line
  when /^Hyper-Threading IS/
    output = true
  when output && /^numa/ 
    key = "#{line}"
  when output && /\d+.\d+/ && key.empty?
    results[key] = line.to_f
  end
end

results.each { |key, value| puts "#{key}.seconds: #{value}" } if !results.empty?
