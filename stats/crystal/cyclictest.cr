#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath(PROGRAM_NAME)))

require "#{LKP_SRC}/lib/log"
require "#{LKP_SRC}/lib/string_ext"

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
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
