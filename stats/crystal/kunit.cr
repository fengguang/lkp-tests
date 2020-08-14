#!/usr/bin/env crystal

stats = {} of String => String

while (line = STDIN.gets)
  case line
  when /\d*(not ok|ok).* - (.*)/
    result = $1.strip.tr(" ", "_")
    test = $2.strip.tr(" ", "_")
    stats[test] = result
  end
end

stats.each do |k, v|
  puts k + "." + v + ": 1"
end
