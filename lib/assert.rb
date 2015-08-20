#!/usr/bin/env ruby

# FIXME rli9 leverage an existing lib
def assert(cond, message)
	raise "ASSERT fail: #{message}" unless cond
end