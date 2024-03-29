#!/usr/bin/env crystal

# --------socket thread num=20--------
# 2020-11-10 19:51:31 /lkp/benchmarks/hackbench-git/hackbench/hackbench 20 thread 1000
# Running with 20*40 (== 800) tasks.
# Time: 0.495
# ...

time = [] of Float64

while (line = gets)
  case line
  when /^-+(\w+ \w+ \w+)/
    args = $1.tr(" ", "_")
  when /^Running with .* \(== (\d+)\) tasks/
    tasks = $1.to_i
  when /^Time:/
    time << line.split[1].to_f
  end
end

puts "#{args}_#{tasks}: #{time.sum / time.size}"
