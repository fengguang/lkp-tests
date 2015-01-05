#!/usr/bin/ruby

MAX_MATRIX_COLS = 100

require 'set'

def is_event_counter(name)
	$event_counter_prefixes ||= File.read("#{LKP_SRC}/etc/event-counter-prefixes").split
	$event_counter_prefixes.each { |prefix|
		return true if name.index(prefix) == 0
	}
	return false
end

def is_independent_counter(name)
	$independent_counters ||= Set.new File.read("#{LKP_SRC}/etc/independent-counters").split
	$independent_counters.include? name
end

def max_cols(matrix)
	cols = 0
	matrix.each { |k, v|
		cols = v.size if cols < v.size
	}
	return cols
end

def matrix_fill_missing_zeros(matrix)
	cols = matrix['stats_source'].size
	matrix.each { |k, v|
		while v.size < cols
			v << 0
		end
	}
	return matrix
end

def add_performance_per_watt(stats, matrix)
	watt = stats['pmeter.Average_Active_Power']
	return unless watt and watt > 0

	kpi_stats = load_yaml("#{LKP_SRC}/etc/index-perf.yaml")
	return unless kpi_stats

	performance = 0
	kpi_stats.each { |stat, weight|
		next if stat == 'boot-time.dhcp'
		next if stat == 'boot-time.boot'
		next if stat.index 'iostat.' and not stats['dd.startup_time']

		value = stats[stat]
		if (value)
			if (weight < 0)
				value = 1 / value
				weight = -weight
			end
			performance += value * weight
		end
	}

	return unless performance > 0

	stats['performance_per_watt'] = performance / watt
	matrix['performance_per_watt'] = [performance / watt]
end

def create_stats_matrix(result_root)
	stats = {}
	matrix = {}

	create_programs_hash "stats/**/*"
	monitor_files = Dir["#{result_root}/*.{json,json.gz}"]

	monitor_files.each { |file|
		case file
		when /\.json$/
			monitor = File.basename(file, '.json')
		when /\.json\.gz$/
			monitor = File.basename(file, '.json.gz')
		end

		next if monitor == 'stats' # stats.json already created?
		next if monitor == 'matrix'
		unless $programs[monitor] or monitor =~ /.+\.time$/
			STDERR.puts "skip unite #{file}: #{monitor} not in #{$programs.keys}"
			next
		end

		monitor_stats = load_json file
		sample_size = max_cols(monitor_stats)
		monitor_stats.each { |k, v|
			next if k == "#{monitor}.time"
			if v.size == 1
				stats[k] = v[0]
			elsif is_independent_counter k
				stats[k] = v.sum
			elsif is_event_counter k
				stats[k] = v[-1] - v[0]
			else
				stats[k] = v.sum / sample_size
			end
			stats[k + '.max'] = v.max if should_add_max_latency k
		}
		matrix.merge! monitor_stats
	}

	add_performance_per_watt(stats, matrix)
	save_json(stats, result_root + '/stats.json')
	save_json(matrix, result_root + '/matrix.json', compress=true)
	return stats
end

def matrix_average(matrix)
	avg = {}
	matrix.each { |k, v| avg[k] = v.average }
	avg
end

def matrix_stddev(matrix)
	stddev = {}
	matrix.each { |k, v| stddev[k] = v.standard_deviation }
	stddev
end

def load_matrix_file(matrix_file)
	matrix = nil
	begin
		matrix = load_json(matrix_file) if File.exists? matrix_file
	rescue Exception
		return nil
	end
	return matrix
end

def shrink_matrix(matrix)
	n = matrix['stats_source'].size - MAX_MATRIX_COLS
	if n > 1
		empty_keys = []
		matrix.each { |k, v|
			v.shift n
			empty_keys << k if v.empty?
		}
		empty_keys.each { |k| matrix.delete k }
	end
end

def unite_to(stats, matrix_root)
	matrix_file = matrix_root + '/matrix.json'

	matrix = load_matrix_file(matrix_root + '/matrix.json')
	matrix = load_matrix_file(matrix_root + '/matrix.yaml') unless matrix
	matrix = {} unless matrix

	old_stats_sources = matrix['stats_source'] || []
	files = Dir["#{matrix_root}/**/stats.json"]

	if old_stats_sources.size + 1 != files.size
		matrix = matrix_from_stats_files files
	else
		matrix = add_stats_to_matrix(stats, matrix)
		shrink_matrix(matrix)
	end

	save_json(matrix, matrix_file)
	matrix = matrix_fill_missing_zeros(matrix)
	matrix.delete 'stats_source'
	begin
		save_json(matrix_average(matrix), matrix_root + '/avg.json')
		save_json(matrix_stddev(matrix), matrix_root + '/stddev.json')
	rescue TypeError
		STDERR.puts "matrix contains non-number values, move to #{matrix_file}-bad"
		FileUtils.mv matrix_file, matrix_file + '-bad', :force => true   # never raises exception
	end
end

# serves as locate db
def save_paths(result_root, user)
	paths_file = "/lkp/paths/#{Time.now.strftime('%F')}-#{user}"

	File.open(paths_file, "a") { |f|
		f.puts(result_root)
	}
end

