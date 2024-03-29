#!/usr/bin/env crystal

require "../../lib/log"
require "../../lib/string_ext"

while (line = STDIN.gets)
  line = line.to_s.remediate_invalid_byte_sequence(replace: "_") unless line.to_s.valid_encoding?
  case line
  when /^# Thread/
    next
  when /^# (\/dev\/cpu_dma_latency) set to (.+)us/
    cpu_dma_latency = $1.downcase
    val = $2
    puts "#{cpu_dma_latency}: #{val}"
  when /^# (.*):(.+)/
    val = $2
    type = $1.downcase.gsub(" ", "_")
    puts "#{type}: #{val}"
  end
end
