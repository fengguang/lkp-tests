#!/usr/bin/env ruby

# rli9 FIXME: leverage an existing lib
def assert(cond, message)
  raise "ASSERT fail: #{message}" unless cond
end
