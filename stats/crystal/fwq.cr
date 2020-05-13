#!/usr/bin/env crystal

RESULT_ROOT = ENV["RESULT_ROOT"]

require "../../lib/noise"

PDEL = 10

data = Array(Int32).new
files = Dir["#{RESULT_ROOT}/results/fwq_*_times.dat"]
files.each do |file|
  sfdata = File.read(file).split
  n = sfdata.size
  ndel = n * PDEL / 100
  sfdata#[n - ndel, ndel]
  sfdata#[0, ndel]
  data.concat(sfdata.map(&.to_i))
end

exit if data.empty?

n = Noise.new("fwq", data)
n.analyse
n.log
