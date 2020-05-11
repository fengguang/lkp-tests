#!/usr/bin/env crystal

mtotal = nil
munit = nil
mused = Array(Int32).new

STDIN.each_line do |line|
  case line
  when /^time:/
    puts line
  else
    key, value, unit = line.split
    key = key.chomp(":")
    value = value.to_i
    puts "#{key}: #{value}"
    mtotal ||= value if key == "MemTotal"
    if key == "MemFree"
      mused << mtotal - value if !mtotal.nil?
      munit ||= unit
      puts "Memused: #{mused.last}"
    end
  end
end

puts "max_used_#{munit}: #{mused.max}"
