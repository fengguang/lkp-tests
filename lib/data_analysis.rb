#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require "#{LKP_SRC}/lib/statistics"
require "#{LKP_SRC}/lib/common"

def auto_range(max_level = 6, min_level = 0)
  (min_level..max_level).map do |ul|
    (1..9).map do |l|
      l * (10**ul)
    end
  end.flatten + [10**(max_level + 1)]
end

def histogram(data, range = nil, params = {})
  no_percent = params[:no_percent]
  accumulate = params[:accumulate]

  range ||= auto_range
  total = data.size
  start = 0
  hist = range.map do |lc|
    next nil if start >= total
    nstart = data.index { |l| l >= lc } || total
    num = if accumulate
            nstart
          else
            nstart - start
          end
    start = nstart
    num
  end.compact
  if start < data.size
    hist += [data.size - start]
  else
    range = range.slice(0, hist.size)
  end

  hist = hist.map { |n| n * 100.0 / total } unless no_percent

  [range, hist]
end

TIME_UNITS = ['u', 'm', ''].freeze

def format_time(val, unit = 'u')
  (TIME_UNITS.index(unit)...TIME_UNITS.size).each do |ui|
    u = TIME_UNITS[ui]
    return format_number(val) + u + 's' if val < 1000 || ui == TIME_UNITS.size - 1

    val /= 1000.0
  end
end

def print_histogram(range, hist, params = {})
  with_range = params[:with_range]
  as_time = params[:as_time]
  unit = params[:unit] || 'u'
  to_plot = params[:to_plot]
  no_extra = params[:no_extra]

  format_level = ->(l) { as_time ? format_time(l, unit) : format_number(l) }

  format_to_plot = ->(n) { to_plot ? "\t" + format_number(n) : '' }

  prev = 0
  range.each_with_index do |lc, i|
    printf '%s-', format_level.call(prev) if with_range
    printf("%s\t%s%s", format_level.call(lc),
           format_number(hist[i]), format_to_plot.call(i + 1))
    prev = lc
    printf "\n"
  end
  return unless !no_extra && hist.size > range.size

  printf("%s+\t%s%s\n", format_level.call(range[-1]),
         format_number(hist[-1]), format_to_plot.call(range.size + 1))
end

def percentile(data, points = [90, 95, 99])
  points.map do |p|
    [p, data[data.size * 0.01 * p]]
  end
end
