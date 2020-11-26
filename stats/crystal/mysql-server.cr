#!/usr/bin/env crystal

results = [] of String

while (line = STDIN.gets)
  case line
    # The output is as below:
    # 200706 14:35:48 [ 99%] main.subquery_sj_innodb_all              w8  [ pass ]    140
    # 200706 14:35:52 [ 99%] main.ssl_dynamic_persisted               w1  [ fail ]   5953
    # 200706 14:35:59 [ 99%] main.mysql_upgrade_grant                 w7  [ skipped ]  80805
  when /\[\s*\d+%\]/
    results << line.split(']')[1].split[0] + ".pass: 1" if line.includes?("[ pass ]")
    results << line.split(']')[1].split[0] + ".fail: 1" if line.includes?("[ fail ]")
    results << line.split(']')[1].split[0] + ".skip: 1" if line.includes?("[ skipped ]")
  end
end

results.each do |item|
  puts item
end
