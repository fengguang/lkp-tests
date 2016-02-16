#!/usr/bin/env ruby

class Time
	def next_month(i = 1)
		year, month = self.year, self.month + i
		year, month = year + 1, month - 12 if month > 12
		Time.new(year, month)
	end

	def prev_month(i = 1)
		year, month = self.year, self.month - i
		year, month = year - 1, month + 12 if month <= 0
		Time.new(year, month)
	end

	def next_day
		date = self + 24 * 3600
		Time.new(date.year, date.month, date.day)
	end
end