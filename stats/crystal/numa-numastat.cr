#!/usr/bin/env crystal

nr = 0

STDIN.each_line do |line|
  case line
  when /^time:/
    puts line
  when /^node:/
    _node, nr = line.split
  when /^ (\d+)$/
    puts "node#{nr}: #{$1}"
  else
    key, value = line.split
    puts "node#{nr}.#{key}: #{value}"
  end
end
