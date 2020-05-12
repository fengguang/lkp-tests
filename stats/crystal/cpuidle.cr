#!/usr/bin/env crystal


require "../../lib/statistics"

samples = {} of String => Array(Int32)

def show_samples(samples)
  samples.each do |k, v|
    puts k + ": " + v.sum.to_s
  end
  samples.clear
end

STDIN.each_line do |line|
  case line
  when /^time: /
    show_samples samples
  when /^cpu\d+\.([^:]+): (.*)/
    samples[$1] ||= [] of Int32
    samples[$1] << $2.to_i
  end
end

show_samples samples
