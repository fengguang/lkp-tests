#!/usr/bin/env crystal

mtotal = nil
munit = nil
mused = []

STDIN.each_line do |line|
  case line
  when /^time:/
    puts line
  else
    key, value, unit = line.split
    key = key.chomp(":")
    puts "#{key}: #{value}"
    value = value.to_i
    mtotal ||= value if key == "MemTotal"
    if key == "MemFree"
      mused << mtotal - value
      munit ||= unit
      puts "Memused: #{mused.last}"
    end
  end
end

puts "max_used_#{munit}: #{mused.max}"
