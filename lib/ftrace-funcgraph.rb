#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']
RESULT_ROOT ||= ENV['RESULT_ROOT']

require "#{LKP_SRC}/lib/common.rb"
require "#{LKP_SRC}/lib/ftrace.rb"
require "#{LKP_SRC}/lib/statistics.rb"
require "#{LKP_SRC}/lib/data_analysis.rb"

PERCT_POINTS = (5..9).map { |n| n * 10 } + [95, 99]

def analyze
  functions_samples = Hash.new()
  zopen("#{RESULT_ROOT}/ftrace.data") do |f|
    trace = FGTrace.new(f)
    trace.each do |s|
      functions_samples[s.func] ||= Array.new
      functions_samples[s.func] << s.duration
    end
  end
  functions_samples.each do |func, samples|
    samples.sort!
    perct = percentile(samples, PERCT_POINTS)
    perct.each do |p, v|
      puts "#{func}.#{p}th: #{v}"
    end
    puts "#{func}.min: #{samples[0]}"
    puts "#{func}.max: #{samples[-1]}"
    puts "#{func}.avg: #{samples.average}"
    puts "#{func}.samples: #{samples.size}"
  end
end
