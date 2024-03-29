#!/usr/bin/env crystal

while (line = STDIN.gets)
  case line
  when /^munmap use (\d+)ms (\d+)ns\/time, memory access uses (\d+) times\/thread\/ms, cost (\d+)ns\/time$/
    puts "munmap_ms: " + $1
    puts "munmap_ns_time: " + $2
    puts "mem_acc_time_thread_ms: " + $3
    puts "mem_acc_cost_ns_time: " + $4
  end
end
