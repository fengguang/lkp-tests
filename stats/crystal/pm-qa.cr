#!/usr/bin/env crystal

stats = {} of String => String
while (line = STDIN.gets)
  case line
  when /^### (\w+_\d+):$/
    item = $1
    stats[item] = "" unless stats.has_key?(item)
  when /^(\w+_\d+): (fail|pass|skip|ignored_by_lkp)$/
    item = $1
    result = $2
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
