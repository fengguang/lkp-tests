#!/usr/bin/env crystal

RESULT_ROOT = ENV["RESULT_ROOT"]

require "../../lib/common"
require "../../lib/log"

PDEL = 10

data = [] of Int32
files = Dir["#{RESULT_ROOT}/results/ftq_*.dat*"]
if files.empty?
  log_error "can not find any log file at #{RESULT_ROOT}/results/"
  exit
end
files.each do |file|
  zopen(file) do |f|
    rdata = f.gets_to_end
    n = (rdata =~ /^[^#]/)
    if n
      rdata.byte_slice?(n, rdata.size)
    end
    sfdata = rdata.to_s.split(/ |\n/)
    sfdata.delete("")
    sfdata_temp = [] of String
    sfdata.each_with_index do |x, i|
      if i.odd?
        sfdata_temp << x
      end
    end
    n = sfdata_temp.size
    ndel = (n * PDEL / 100).to_i
    data.concat(sfdata_temp[ndel, n - ndel - 1].map { |x| x.to_i })
  end
end

data.sort!
mean = data[(data.size / 2).to_i]
max = data.last
samples = data.size

printf "max: %d\n", max
printf "mean: %d\n", mean

perf_levels = [1, 25, 50, 75, 95, 98]

start = 0
perf_num_levels = [] of Array(Float64 | Int32)
perf_levels.each do |level|
  lc = mean * level / 100
  nstart = data.bsearch_index { |n| n >= lc }
  nstart ||= samples
  num = nstart * 1_000_000.0 / samples
  start = nstart
  perf_num_levels << [level, num]
end

perf_num_levels.each do |x|
  printf "noise.%d%%: %g\n", 100 - x[0], x[1]
end
