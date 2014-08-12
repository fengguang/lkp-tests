#!/usr/bin/ruby

def is_valid_stats_range(stats_field, num)
	monitor = stats_field.split('.')[0]
	range_file = "#{LKP_SRC}/etc/valid-range-#{monitor}.yaml"
	if File.exist? range_file
		stats_range = load_json range_file
		stats_range.each { |k, v|
			if stats_field =~ %r{^#{k}$}
				min = v[0]
				max = v[1]
				return false if num < min or num > max
			end
		}
	end

	return true
end

