#!/usr/bin/env ruby

LKP_SRC ||= ENV["LKP_SRC"]

require "#{LKP_SRC}/lib/statistics.rb"
require "#{LKP_SRC}/lib/common.rb"

def auto_range(max_level = 6, min_level = 0)
  (min_level..max_level).map { |ul|
    (1..9).map { |l|
      l * (10 ** ul)
    }
  }.flatten + [10 ** (max_level + 1)]
end

def histogram(data, range = nil, percent = true)
  range ||= auto_range
  total = data.size
  start = 0
  hist = range.map { |lc|
    next nil if start >= total
    nstart = data.bsearch_index { |l| l >= lc } || total
    num = nstart - start
    start = nstart
    num
  }.compact
  if start < data.size
    hist += [data.size - start]
  else
    range = range.slice(0, hist.size)
  end

  if percent
    hist = hist.map { |n| n * 100.0 / total }
  end

  [range, hist]
end

TIME_UNITS = ['u', 'm', '']

def format_time(val, unit = 'u')
  (TIME_UNITS.index(unit)...TIME_UNITS.size).each { |ui|
    u = TIME_UNITS[ui]
    if val < 1000 || ui == TIME_UNITS.size - 1
      return format_number(val) + u + 's'
    else
      val /= 1000.0
    end
  }
end

def print_histogram(range, hist, params = {})
  with_range = params[:with_range]
  as_time = params[:as_time]
  unit = params[:unit] || 'u'
  to_plot = params[:to_plot]

  format_level = ->l{
    as_time ? format_time(l, unit) : format_number(l)
  }

  format_to_plot = ->n{
    to_plot ? "\t" + format_number(n) : ""
  }

  prev = 0
  range.each_with_index { |lc, i|
    if with_range
      printf "%s-", format_level.(prev)
    end
    printf("%s\t%s%s", format_level.(lc),
           format_number(hist[i]), format_to_plot.(i+1))
    prev = lc
    printf "\n"
  }
  if hist.size > range.size
    printf("%s+\t%s%s\n", format_level.(range[-1]),
           format_number(hist[-1]), format_to_plot.(range.size + 1))
  end
end

def percentile(data, points = [90, 95, 99])
  points.map { |p|
    [p, data[data.size * 0.01 * p]]
  }
end
