#!/usr/bin/env crystal

stats = {}
while (line = STDIN.gets)
  case line
  when /^### (\w+_\d+):$/
    item = Regexp.last_match[1]
    stats[item] = "" unless stats.has_key?(item)
  when /^(\w+_\d+): (fail|pass|skip|ignored_by_lkp)$/
    item = Regexp.last_match[1]
    result = Regexp.last_match[2]
    stats[item] = "#{result}: 1" unless stats.has_key?(item) && !stats[item].empty?
  end
end

stats.each do |k, v|
  if v.empty?
    puts k + ".skip: 1"
  else
    puts k + "." + v
  end
end
