#!/usr/bin/env crystal

# Input example:
# 7.403: Running...
# 9.404: Run took 2 seconds...
# 9.405: Per-Operation Breakdown
# closefile2           1000ops      500ops/s   0.0mb/s    0.041ms/op [0.003ms - 27.835ms]
# closefile1           1000ops      500ops/s   0.0mb/s    0.029ms/op [0.004ms - 7.089ms]
# writefile2           1000ops      500ops/s   7.8mb/s    0.340ms/op [0.106ms - 34.186ms]
# createfile2          1000ops      500ops/s   0.0mb/s    0.351ms/op [0.131ms - 22.371ms]
# readfile1            1001ops      500ops/s   7.8mb/s    0.201ms/op [0.061ms - 12.895ms]
# openfile1            1001ops      500ops/s   0.0mb/s    0.125ms/op [0.034ms - 10.298ms]
# 9.405: IO Summary:  6002 ops 3000.256 ops/s 500/500 rd/wr  15.6mb/s 0.181ms/op

while (line = STDIN.gets)
  case line
  when /IO Summary:\s+(\d+)\s+ops\s+([\d.]+)\s+ops\/s\s+(\d+)\/(\d+)\s+rd\/wr\s+([\d.]+)mb\/s\s+([\d.]+)ms\/op/
    puts "sum_operations: " + $1
    puts "sum_operations/s: " + $2
    puts "sum_reads/s: " + $3
    puts "sum_writes/s: " + $4
    puts "sum_bytes_mb/s: " + $5
    puts "sum_time_ms/op: " + $6
  end
end
