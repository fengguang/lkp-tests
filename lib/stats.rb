#!/usr/bin/ruby

MARGIN_SHIFT = 5
MAX_RATIO = 5

LKP_SRC ||= ENV['LKP_SRC']

require "set.rb"
require "#{LKP_SRC}/lib/git.rb"
require "#{LKP_SRC}/lib/yaml.rb"
require "#{LKP_SRC}/lib/result.rb"
require "#{LKP_SRC}/lib/bounds.rb"
require "#{LKP_SRC}/lib/statistics.rb"

$metric_add_max_latency	= IO.read("#{LKP_SRC}/etc/add-max-latency").split("\n")
$metric_latency		= IO.read("#{LKP_SRC}/etc/latency").split("\n")
$metric_failure		= IO.read("#{LKP_SRC}/etc/failure").split("\n")
$functional_tests	= Set.new IO.read("#{LKP_SRC}/etc/functional-tests").split("\n")
$perf_metrics_threshold = YAML.load_file "#{LKP_SRC}/etc/perf-metrics-threshold.yaml"
$perf_metrics_prefixes	= File.read("#{LKP_SRC}/etc/perf-metrics-prefixes").split

$perf_metrics_patterns	= File.read("#{LKP_SRC}/etc/perf-metrics-patterns").split
$perf_metrics_re	= Regexp.new $perf_metrics_patterns.join('|')

metrics_blacklist  = File.read("#{LKP_SRC}/etc/blacklist").split
$metrics_blacklist_re = Regexp.new metrics_blacklist.join('|')

# => ["tcrypt.", "hackbench.", "dd.", "xfstests.", "aim7.", ..., "oltp.", "fileio.", "dmesg."]
def test_prefixes()
	stats = Dir["#{LKP_SRC}/stats/**/*"].map { |path| File.basename path }
	tests = Dir["#{LKP_SRC}/tests/**/*"].map { |path| File.basename path }
	tests = stats & tests
	tests.delete 'wrapper'
	tests.push 'kmsg'
	tests.push 'dmesg'
	tests.push 'stderr'
	tests.push 'last_state'
	return tests.map { |test| test + '.' }
end
$test_prefixes = test_prefixes
$perf_metrics_prefixes.concat $test_prefixes

def is_perf_metric(name)
	return true if name =~ $perf_metrics_re

	$perf_metrics_prefixes.each { |prefix|
		return true if name.index(prefix) == 0
	}

	return false
end

def is_valid_perf_metric(name, delta, max)

	$perf_metrics_threshold.each { |k, v|
		next unless name =~ %r{^#{k}$}
		return false if max < v
		return false if delta < v / 2 and v.class == Fixnum
		return true
	}

	case name
	when /^iostat/
		return max > 1
	when /^pagetypeinfo/, /^buddyinfo/, /^slabinfo/
		return delta > 100
	when /^proc-vmstat/, /meminfo/
		return max > 1000
	when /^lock_stat/
		case name
		when 'waittime-total'
			return delta > 10000
		when 'holdtime-total'
			return delta > 100000
		when /time/
			return delta > 1000
		else
			return delta > 10000
		end
	when /^interrupts/, /^softirqs/
		return max > 10000
	end
	return true
end

def is_changed_stats(sorted_a, min_a, mean_a, max_a,
		     sorted_b, min_b, mean_b, max_b,
		     is_failure_stat, is_latency_stat, options)

	if is_failure_stat
		return max_a != max_b
	end

	if is_latency_stat
		if min_a > max_b + (max_b - min_b) or
		   min_b > max_a + (max_a - min_a)
			return true
		elsif options['distance']
			return false unless max_a > 2 * options['distance'] * max_b and mean_a > options['distance'] * max_b or
					    max_b > 2 * options['distance'] * max_a and mean_b > options['distance'] * max_a
		else
			return false unless max_a > 3 * max_b or
				            max_b > 3 * max_a
		end
		return true
	end

	len_a = max_a - min_a
	len_b = max_b - min_b
	if options['variance']
		return true if len_a * mean_b > options['variance'] * len_b * mean_a
		return true if len_b * mean_a > options['variance'] * len_a * mean_b
	elsif options['distance']
		if Fixnum === max_a and (min_a - max_b == 1 or min_b - max_a == 1)
			return false
		end
		if sorted_a.size < 3 or sorted_b.size < 3
			min_gap = [len_a, len_b].max * options['distance']
			return true if min_b - max_a > min_gap
			return true if min_a - max_b > min_gap
			return false
		end
		return true if min_b > max_a and (min_b - max_a) > (mean_b - mean_a) / 2
		return true if min_a > max_b and (min_a - max_b) > (mean_a - mean_b) / 2
	else
		return true if min_b > mean_a and mean_b > max_a
		return true if min_a > mean_b and mean_a > max_b
	end
	return false
end

# sort key for reporting all changed stats
def stat_relevance(record)
	stat = record['stat']
	if stat[0..9] == 'lock_stat.'
		relevance = 5
	elsif $test_prefixes.include? stat.sub(/\..*/, '.')
		relevance = 100
	elsif is_perf_metric(stat)
		relevance = 1
	else
		relevance = 10
	end
	return [ relevance, [record['ratio'], 5].min ]
end

def sort_stats(stat_records)
	stat_records.keys.sort_by { |stat|
		order1 = 0
		order2 = 0.0
		stat_records[stat].each { |record|
			key = stat_relevance(record)
			order1 = key[0]
			order2 += key[1]
		}
		order2 /= $stat_records[stat].size
		- order1 - order2
	}
end

def matrix_cols(hash_of_array)
	if hash_of_array == nil
		0
	elsif hash_of_array.empty?
		0
	elsif a = hash_of_array['stats_source']
		a.size
	else
		[ hash_of_array.values[0].size, hash_of_array.values[-1].size ].max
	end
end

def load_release_matrix(matrix_file)
	begin
		matrix = load_json matrix_file
	rescue Exception
		matrix = nil
	end

	return matrix
end

def install_path(kconfig, commit)
	"/kernel/#{kconfig}/#{commit}"
end

def is_functional_test(path)
	rp = Result_path.new
	rp.parse_result_root path
	$functional_tests.include? rp['testcase']
end

def load_base_matrix(matrix_path, head_matrix)
	matrix_path = File.realpath matrix_path
	matrix_path = File.dirname matrix_path if File.file? matrix_path
	matrix_path = File.dirname matrix_path if File.basename(matrix_path) =~ /^[0-9]+$/
	commit        = File.basename matrix_path
	__result_root = File.dirname matrix_path

	matrix = {}
	tags_merged = []

	if commit_exists(commit)
		version, is_exact_match = last_linus_release_tag commit
	else
		kconfig = File.basename __result_root
		context_file = install_path(kconfig, commit) + "/context.yaml"
		version = nil
		if File.exist? context_file
			context = YAML.load_file context_file
			version = context['rc_tag']
			is_exact_match = false
		end
		unless version
			STDERR.puts "Cannot get base RC commit for #{commit}"
			STDERR.puts caller
			return nil
		end
	end
	order = tag_order(version)

	cols = 0
	linus_tags.each { |tag|
		o = tag_order(tag)
		next if o >  order
		next if o == order and is_exact_match
		next if is_exact_match and tag =~ /^#{version}-rc[0-9]+$/
		break if tag =~ /\.[0-9]+$/ and tags_merged.size >= 2 and cols >= 10

		base_matrix_file = "#{__result_root}/#{tag}/matrix.json"
		next unless File.exist? base_matrix_file

		rc_matrix = load_release_matrix base_matrix_file
		if rc_matrix
			add_stats_to_matrix(rc_matrix, matrix)
			tags_merged << tag
			cols += matrix['stats_source'].size
			break if tags_merged.size >= 3 and cols >= 20
			break if tag =~ /-rc1$/ and cols >= 3
		end
	}

	if matrix.size > 0
		if cols >= 3 or
		  (cols >= 1 and is_functional_test matrix_path) or
		  head_matrix['last_state.is_incomplete_run'] or
		  head_matrix['dmesg.boot_failures'] or
		  head_matrix['stderr.has_stderr']
			puts "compare with release matrix: #{matrix_path} #{tags_merged}" if ENV["LKP_VERBOSE"]
			return matrix
		else
			puts "release matrix too small: #{matrix_path} #{tags_merged}" if ENV["LKP_VERBOSE"]
			return nil
		end
	else
		puts "found no release matrix: #{matrix_path}" if ENV["LKP_VERBOSE"]
		return nil
	end
end

def is_failure(stats_field)
	$metric_failure.each { |pattern| return true if stats_field =~ %r{^#{pattern}} }
	return false
end

def is_latency(stats_field)
	$metric_latency.each { |pattern| return true if stats_field =~ %r{^#{pattern}} }
	return false
end

def should_add_max_latency(stats_field)
	$metric_add_max_latency.each { |pattern| return true if stats_field =~ %r{^#{pattern}$} }
	return false
end

def sort_remove_margin(array, max_margin=nil)
	return nil if not array

	margin = array.size  >> MARGIN_SHIFT
	margin = [margin, max_margin].min if max_margin

	array = array.sorted
	array = array[margin..-margin-1]
end

# NOTE: array *must* be sorted
def get_min_mean_max(array)
	return [ 0, 0, 0 ] if not array

	[ array[0], array[array.size/2], array[-1] ]
end

# Filter out data generated by incomplete run
def filter_incomplete_run(hash)
	is_incomplete_runs = hash['last_state.is_incomplete_run']
	return unless is_incomplete_runs

	delete_index_list = []
	is_incomplete_runs.each_with_index { |val, index|
		if val == 1
			delete_index_list << index
		end
	}
	delete_index_list.reverse!

	hash.each { |k,v|
		delete_index_list.each { |index|
			v.delete_at(index)
		}
	}

	hash.delete 'last_state.is_incomplete_run'
end

# b is the base of compare (eg. rc kernels) and normally have more samples than
# a (eg. the branch HEADs)
def __get_changed_stats(a, b, options)
	changed_stats = {}

	if options['ignore-incomplete-run']
		filter_incomplete_run(a)
		filter_incomplete_run(b)

		is_all_run_incomplete = b['stats_source'].size == 0
		return nil if is_all_run_incomplete
	end

	is_incomplete_run = a['last_state.is_incomplete_run'] ||
			    b['last_state.is_incomplete_run']
	resize = options['resize']

	if b['stats_source']
		good_commit = File.basename File.dirname File.dirname b['stats_source'][0]
		STDERR.puts "#{good_commit} not a commit, stats_source is #{b['stats_source']} #{a['stats_source']}" unless is_commit(good_commit)
	end

	cols_a = matrix_cols a
	cols_b = matrix_cols b

	if options['variance']
		return nil if cols_a < 10 or cols_b < 10
	end

	b_monitors = {}
	b.keys.each { |k| b_monitors[k.split('.')[0]] = true }

	b.keys.each { |k| a[k] = [0] * cols_a unless a.include?(k) }

	a.each { |k, v|
		next if String === v[-1]
		next if options['perf'] and not is_perf_metric k
		next if is_incomplete_run and k !~ /^(dmesg|last_state|stderr)\./
		next if k =~ $metrics_blacklist_re

		is_failure_stat = is_failure k
		is_latency_stat = is_latency k
		if is_failure_stat or is_latency_stat
			max_margin = 0
		else
			max_margin = 3
		end

		unless is_failure_stat
			# for none-failure stats field, we need asure that
			# at least one matrix has 3 samples.
			next if cols_a < 3 and cols_b < 3
		end

		next unless b[k] or
			is_failure_stat or
			(k =~ /^(lock_stat|perf-profile|latency_stats)\./ and b_monitors[$1])

		b_k = b[k] || [0] * cols_b
		while b_k.size < cols_b
			b_k << 0
		end
		while v.size < cols_a
			v << 0
		end

		sorted_b = sort_remove_margin b_k, max_margin
		min_b, mean_b, max_b = get_min_mean_max sorted_b
		next unless max_b

		v.pop(v.size - resize) if resize and v.size > resize

		max_margin = 1 if b_k.size <= 3 and max_margin > 1
		sorted_a = sort_remove_margin v, max_margin
		min_a, mean_a, max_a = get_min_mean_max sorted_a
		next unless max_a

		next unless is_changed_stats(sorted_a, min_a, mean_a, max_a,
					     sorted_b, min_b, mean_b, max_b,
					     is_failure_stat, is_latency_stat, options)

		max = [max_b, max_a].max
		x = max_a - min_a
		z = max_b - min_b
		x = z if sorted_a.size <= 2 and x < z
		ratio = MAX_RATIO
		if mean_a > mean_b
			y = min_a - max_b
			delta = mean_a - mean_b
			ratio = mean_a.to_f / mean_b if mean_b > 0
		else
			y = min_b - max_a
			delta = mean_b - mean_a
			ratio = mean_b.to_f / mean_a if mean_a > 0
		end
		y = 0 if y < 0
		ratio = MAX_RATIO if ratio > MAX_RATIO

		next unless ratio > 1.01 # time.elapsed_time only has 0.01s precision
		next unless ratio > 1.1 or is_perf_metric(k)
		next unless is_valid_perf_metric(k, delta, max)

		interval_a = "[ %-10.5g - %-10.5g ]" % [ min_a, max_a ]
		interval_b = "[ %-10.5g - %-10.5g ]" % [ min_b, max_b ]
		interval = interval_a + " -- " + interval_b

		changed_stats[k] = { 'stat'		=> 	k,
				     'interval'		=>	interval,
				     'a'		=>	sorted_a,
				     'b'		=>	sorted_b,
				     'ttl'		=>	Time.now,
				     'is_failure'	=>	is_failure_stat,
				     'is_latency'	=>	is_latency_stat,
				     'ratio'		=>	ratio,
				     'delta'		=>	delta,
				     'mean_a'		=>	mean_a,
				     'mean_b'		=>	mean_b,
				     'x'		=>	x,
				     'y'		=>	y,
				     'z'		=>	z,
				     'min_a'		=>	min_a,
				     'max_a'		=>	max_a,
				     'min_b'		=>	min_b,
				     'max_b'		=>	max_b,
				     'max'		=>	max,
				     'nr_run'		=>	v.size,
		}
		changed_stats[k]['good_commit'] = good_commit if good_commit
	}

	return changed_stats
end

def load_matrices_to_compare(matrix_path1, matrix_path2 = nil)
	begin
		a = search_load_json matrix_path1
		return [nil, nil] unless a
		if matrix_path2
			b = search_load_json matrix_path2
		else
			b = load_base_matrix matrix_path1, a
		end
	rescue Exception
		return [nil, nil]
	end
	return [a, b]
end

def get_changed_stats(matrix_path1, matrix_path2 = nil, options = {})
	a, b = load_matrices_to_compare matrix_path1, matrix_path2
	return nil if a == nil or b == nil

	changed_stats = __get_changed_stats(a, b, options)
	return changed_stats
end

def add_stats_to_matrix(stats, matrix)
	columns = 0
	matrix.each { |k, v| columns = v.size if columns < v.size }
	stats.each { |k, v|
		matrix[k] ||= []
		while matrix[k].size < columns
			matrix[k] << 0
		end
		if Array === v
			matrix[k].concat v
		else
			matrix[k] << v
		end
	}
	matrix
end


def matrix_from_stats_files(stats_files, add_source = true)
	matrix = {}
	stats_files.each { |stats_file|
		stats = load_json stats_file
		unless stats
			STDERR.puts "WARN: empty or non-exist stats file #{stats_file}"
			next
		end
		stats['stats_source'] ||= stats_file if add_source
		matrix = add_stats_to_matrix(stats, matrix)
	}
	matrix
end

def samples_fill_missing_zeros(matrix, key)
	size = matrix_cols matrix
	samples = matrix[key] || [0] * size
	while samples.size < size
		samples << 0
	end
	return samples
end

