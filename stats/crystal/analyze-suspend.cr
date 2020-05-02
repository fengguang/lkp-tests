#!/usr/bin/env crystal

stats_name = "fail: 1"

while (line = STDIN.gets)
  case line
  when /^analyze_suspend test done/
    stats_name = "pass: 1"
    break
  end
end

puts stats_name
