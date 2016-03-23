#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']

MAX_MATRIX_COLS = 100
STATS_SOURCE_KEY = 'stats_source'

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

	stats['pmeter.performance_per_watt'] = performance / watt
	matrix['pmeter.performance_per_watt'] = [performance / watt]
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
		unless $programs[monitor] or monitor =~ /^ftrace\.|.+\.time$/
			$stderr.puts "skip unite #{file}: #{monitor} not in #{$programs.keys}"
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
		matrix = load_json(matrix_file) if File.exist? matrix_file
	rescue Exception
		return nil
	end
	return matrix
end

def shrink_matrix(matrix, max_cols)
	n = matrix['stats_source'].size - max_cols
	if n > 1
		empty_keys = []
		matrix.each { |k, v|
			v.shift n
			empty_keys << k if v.empty?
		}
		empty_keys.each { |k| matrix.delete k }
	end
end

def matrix_delete_col(matrix, col)
	matrix.each { |k, v|
		v.delete_at col
	}
end

def unite_remove_blacklist_stats(matrix)
	# sched_debug per-cpu stats usually change a lot among multiple running,
	# still keep statistic stats such as avg, min, max, stddev, etc.
	matrix.reject { |k, v|
		k =~ /^sched_debug.*\.[0-9]+$/
	}
end

def unite_to(stats, matrix_root, max_cols = nil, delete = false)
	matrix_file = matrix_root + '/matrix.json'

	matrix = load_matrix_file(matrix_root + '/matrix.json')
	matrix = load_matrix_file(matrix_root + '/matrix.yaml') unless matrix

	if matrix
		dup_col = matrix[STATS_SOURCE_KEY].index stats[STATS_SOURCE_KEY]
		matrix_delete_col(matrix, dup_col) if dup_col
	else
		matrix = {}
	end

	unless delete
		matrix = add_stats_to_matrix(stats, matrix)
	end
	shrink_matrix(matrix, max_cols) if max_cols

	matrix = unite_remove_blacklist_stats(matrix)
	save_json(matrix, matrix_file)
	matrix = matrix_fill_missing_zeros(matrix)
	matrix.delete 'stats_source'
	begin
		save_json(matrix_average(matrix), matrix_root + '/avg.json')
		save_json(matrix_stddev(matrix), matrix_root + '/stddev.json')
	rescue TypeError
		$stderr.puts "matrix contains non-number values, move to #{matrix_file}-bad"
		FileUtils.mv matrix_file, matrix_file + '-bad', :force => true   # never raises exception
	end
	return matrix
end

# serves as locate db
def save_paths(result_root, user)
	paths_file = "/lkp/paths/#{Time.now.strftime('%F')}-#{user}"

	# to avoid confusing between .../1 and .../11, etc. when search/remove, etc.
	result_root += '/' unless result_root.end_with?('/')

	File.open(paths_file, "a") { |f|
		f.puts(result_root)
	}
end

def merge_matrixes(matrixes)
	mresult = {}
	matrixes.each { |m|
		add_stats_to_matrix(m, mresult)
	}
	mresult
end

def check_warn_test_error(matrix, result_root)
	ids = %w(
			last_state.is_incomplete_run
			last_state.exit_fail
			stderr.has_stderr
			phoronix-test-suite.has_failure
		)

	ids.each do |errid|
		samples = matrix[errid]
		next unless samples
		next unless samples.last(10).sum == 10
		next if errid == 'last_state.is_incomplete_run' and matrix['dmesg.boot_failures']
		$stderr.puts "The last 10 results all failed, check: #{errid} #{result_root}"
	end
end

def sort_matrix(matrix, key)
	key_index = matrix.keys.index key
	t = matrix.values.transpose
	t.sort_by! { |vs|
		vs[key_index]
	}
	values = t.transpose
	m = {}
	matrix.keys.each_with_index { |k, i|
		m[k] = values[i]
	}
	m
end

def save_matrix_as_csv(file, matrix, sep = ' ', header = true)
	file.puts matrix.keys.join(sep)
	t = matrix.values.transpose
	t.each { |vs|
		file.puts vs.map { |v| v.to_s }.join(sep)
	}
end

def print_matrix(matrix)
	ks = matrix.map { |k, vs| k.size }.max
	matrix.each { |k, vs|
		printf "%-#{ks}s ", k
		vs.each { |v|
			s = format_number(v)
			printf "%-12s", s
		}
		puts
	}
end

def unite_params(result_root)
	if not File.directory? result_root
		$stderr.puts "#{result_root} is not a directory"
		return false
	end

	result_path = ResultPath.new
	result_path.parse_result_root result_root

	params_file = result_path.params_file
	params_root = File.dirname params_file

	if File.exist? params_file and Time.now - File.ctime(params_root) > 3600
		# no need to update params
		return true
	end

	params = {}
	params = YAML.load_file(params_file) if File.exist? params_file

	job = Job.new
	job.load(result_root + '/job.yaml') rescue return

	job.each_param { |k, v, option_type|
		if params[k]
			if not params[k].include? v
				params[k] << v
			end
		else
			params[k] = [ v ]
		end
	}

	begin
		atomic_save_yaml_json params, params_file
	rescue Exception => e
		$stderr.puts 'unite_params: ' + e.message
	end
end

def unite_stats(result_root, delete = false)
	if not File.directory? result_root
		$stderr.puts "#{result_root} is not a directory"
		return false
	end

	result_root = File.realpath result_root
	_result_root = File.dirname result_root
	__result_root = File.dirname _result_root

	stats = create_stats_matrix(result_root)
	stats['stats_source'] = result_root + '/stats.json'

	unite_to(stats, _result_root, nil, delete)
	begin
		__matrix = unite_to(stats, __result_root, 100, nil, delete)
		check_warn_test_error __matrix, result_root
	rescue Exception
	end

	return true
end
