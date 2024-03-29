#!/usr/bin/env crystal

require "../../lib/log"

stats = Hash(String, String).new
unit = nil

while (line = STDIN.gets)
  case line
  when /This system uses (\d+) bytes per array element/
    stats["element_size_byte"] = $1
  when /Array size = (\d+) \(elements\)/
    stats["array_size"] = $1
  when /Function.*Best Rate (.*) Avg time/
    unit = $1.to_s.strip.tr("/", "p")
  when /(Copy|Scale|Add|Triad)/
    if unit.nil?
      log_error "can not get unit"
      exit
    end
    stats["#{$1.downcase}_bandwidth_#{unit}"] = line.split[1]
  end
end

stats.each do |k, v|
  puts "#{k}: #{v}"
end
