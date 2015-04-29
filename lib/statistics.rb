#!/usr/bin/env ruby
#
# https://www.bcg.wisc.edu/webteam/support/ruby/standard_deviation

# Add methods to Enumerable, which makes them available to Array
module Enumerable

	def sum
		begin
			return self.inject(0) { |acc, i| acc + i }
		rescue TypeError
			STDERR.puts self
			raise
		end
	end

	def average
		return self.sum / self.length.to_f
	end

	def sorted
		s = self.sort
		s.shift while s[0] == -1  # -1 means empty data point
		s
	end

	def mean_sorted
		s = self.sorted
		if s.size <= 2
			[s.average, s]
		else
			[s[s.size/2], s]
		end
	end

	def sample_variance
		avg = self.average
		sum = self.inject(0) { |acc, i| acc + (i - avg)**2 }
		return 1 / self.length.to_f * sum
	end

	def standard_deviation
		return Math.sqrt(self.sample_variance)
	end
end
