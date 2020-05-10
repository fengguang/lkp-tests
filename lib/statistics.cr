#!/usr/bin/env crystal
#
# https://www.bcg.wisc.edu/webteam/support/ruby/standard_deviation

# Add methods to Enumerable, which makes them available to Array


module Enumerable
  def average
    sum / size.to_f
  end

  def sorted
    s = sort
   # s.shift while s[0] == -1 # -1 means empty data point
    if s[0] == -1
      s.shift
    end
    s
  end

  def mean_sorted
    s = sorted
    if s.size <= 2
      [s.average, s]
    else
      [s[s.size / 2], s]
    end
  end

  def sample_variance
    avg = average
    sum =reduce(0) { |acc, i| acc + (i - avg) ** 2 }
    1 / size.to_f * sum
  end

  def standard_deviation
    Math.sqrt(sample_variance)
  end
end
