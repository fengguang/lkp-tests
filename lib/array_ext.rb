#!/usr/bin/env ruby

class Array
  # multiple two arrays via multiple element with same index,
  # return the result array.
  def pos_mulitple(an_arr)
    zip(an_arr).map { |v1, v2| v1 * v2 }
  end

  def sum
    self.inject(0) {|sum, i| sum + i}
  end
end
