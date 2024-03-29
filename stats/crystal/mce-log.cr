#!/usr/bin/env crystal

stats = Hash(String, String).new

item = "mce_log_item"
while (line = STDIN.gets)
  case line
  when /^mce-log-item:(\S+)$/
    item = $1
  when /^(\S+)\.conf: triggers trigger as expected$/
    stats[item + "." + $1] = "pass"
  when /^(\S+)\.conf: triggers did not trigger as expected:/
    stats[item + "." + $1] = "fail"
  when /^(ignored_by_lkp): (.*)/
    stats[$2] = $1
  end
end

stats.each do |k, v|
  puts k + "." + v + ": 1"
end
