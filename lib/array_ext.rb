#!/usr/bin/env ruby

require 'active_support/core_ext/enumerable'

class Array
  # multiple two arrays via multiple element with same index,
  # return the result array.
  def pos_multiple(an_arr)
    zip(an_arr).map { |v1, v2| v1 * v2 }
  end
end
