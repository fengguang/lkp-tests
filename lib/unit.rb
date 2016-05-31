#!/usr/bin/env ruby

def to_seconds(time_spec)
	return time_spec if Fixnum === time_spec
	return time_spec if Float === time_spec

	n = time_spec.to_i

	case time_spec[-1]
	when 'y'
		return n * 3600 * 24 * 365
	when 'w'
		return n * 3600 * 24 * 7
	when 'd'
		return n * 3600 * 24
	when 'h'
		return n * 3600
	when 'm'
		return n * 60
	when 's'
		return n
	else
		return n
	end
end

