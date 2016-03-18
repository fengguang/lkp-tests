#!/usr/bin/env ruby

MARGIN_SHIFT = 5
MAX_RATIO = 5

LKP_SRC ||= ENV['LKP_SRC']

require "set.rb"
require "#{LKP_SRC}/lib/lkp_git"
require "#{LKP_SRC}/lib/git-update.rb" if File.exist?("#{LKP_SRC}/lib/git-update.rb")
require "#{LKP_SRC}/lib/yaml.rb"
require "#{LKP_SRC}/lib/result.rb"
require "#{LKP_SRC}/lib/bounds.rb"
require "#{LKP_SRC}/lib/constant.rb"
require "#{LKP_SRC}/lib/statistics.rb"
require "#{LKP_SRC}/lib/error.rb"

$metric_add_max_latency	= IO.read("#{LKP_SRC}/etc/add-max-latency").split("\n")
$metric_latency		= IO.read("#{LKP_SRC}/etc/latency").split("\n")
$metric_failure		= IO.read("#{LKP_SRC}/etc/failure").split("\n")
$functional_tests	= Set.new IO.read("#{LKP_SRC}/etc/functional-tests").split("\n")
$perf_metrics_threshold = YAML.load_file "#{LKP_SRC}/etc/perf-metrics-threshold.yaml"
$perf_metrics_prefixes	= File.read("#{LKP_SRC}/etc/perf-metrics-prefixes").split

$perf_metrics_re	= load_regular_expressions("#{LKP_SRC}/etc/perf-metrics-patterns")
$metrics_blacklist_re	= load_regular_expressions("#{LKP_SRC}/etc/blacklist")

# => ["tcrypt.", "hackbench.", "dd.", "xfstests.", "aim7.", ..., "oltp.", "fileio.", "dmesg."]
def test_prefixes()
	stats = Dir["#{LKP_SRC}/stats/**/*"].map { |path| File.basename path }
	tests = Dir["#{LKP_SRC}/{tests,daemon}/**/*"].map { |path| File.basename path }
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

def __is_perf_metric(name)
	return true if name =~ $perf_metrics_re

	$perf_metrics_prefixes.each { |prefix|
		return true if name.index(prefix) == 0
	}

	return false
end

def is_perf_metric(name)
	$__is_perf_metric_cache ||= {}
	if $__is_perf_metric_cache.include? name
		$__is_perf_metric_cache[name]
	else
		$__is_perf_metric_cache[name] = __is_perf_metric(name)
	end
end

# Check whether it looks like a reasonable performance change,
# to avoid showing unreasonable ones to humans in compare/mplot output.
def is_reasonable_perf_change(name, delta, max)

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
		if options['distance']
			# auto start bisect only for big regression
			return false if sorted_b.size <= 3 and sorted_a.size <= 3
			return false if sorted_b.size <= 3 and min_a < 2 * options['distance'] * max_b
			return false if max_a < 2 * options['distance'] * max_b
			return false if mean_a < options['distance'] * max_b
			return true
		else
			return true if max_a > 3 * max_b
			return true if max_b > 3 * max_a
			return false
		end
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
	elsif gap = options['gap']
		return true if min_b > max_a and (min_b - max_a) > (mean_b - mean_a) * gap
		return true if min_a > max_b and (min_a - max_b) > (mean_a - mean_b) * gap
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

def vmlinuz_dir(kconfig, compiler, commit)
	"#{KERNEL_ROOT}/#{kconfig}/#{compiler}/#{commit}"
end

def is_functional_test(testcase)
	return true if testcase =~ /^build-/
	$functional_tests.include? testcase
end

def load_base_matrix(matrix_path, head_matrix, options)
	matrix_path = File.realpath matrix_path
	matrix_path = File.dirname matrix_path if File.file? matrix_path

	rp = ResultPath.new
	rp.parse_result_root matrix_path

	puts rp if ENV['LKP_VERBOSE']
	project = options['bisect_project'] || 'linux'
	axis = options['bisect_axis'] || 'commit'

	commit = rp[axis]
	matrix = {}
	tags_merged = []
	working_dir = ENV['SRC_ROOT'] || project_work_tree(project)

	begin
		$git ||= {}
		$git[project] ||= Git.open(project: project, working_dir: working_dir)
		git = $git[project]
	rescue
		$stderr.puts "error: Cannot find project #{project} for bisecting"
		$stderr.puts caller
		return nil
	end

	begin
		version, is_exact_match = git.gcommit(commit).last_release_tag
		puts "project: #{project}, version: #{version}, is exact match: #{is_exact_match}" if ENV['LKP_VERBOSE']
	rescue StandardError => e
		dump_exception e, binding
		return nil
	end

	# FIXME: remove it later; or move it somewhere in future
	if project == 'linux' and not version
		kconfig = rp['kconfig']
		compiler = rp['compiler']
		context_file = vmlinuz_dir(kconfig, compiler, commit) + "/context.yaml"
		version = nil
		if File.exist? context_file
			context = YAML.load_file context_file
			version = context['rc_tag']
			is_exact_match = false
		end
		unless version
			$stderr.puts "Cannot get base RC commit for #{commit}"
			$stderr.puts caller
			return nil
		end
	end

	order = git.release_tag_order(version)
	unless order
		# ERR unknown version v4.3 matrix
		# b/c git repo like /c/repo/linux on inn keeps changing, it is possible
		# that git object is cached in an older time, and v4.3 commit 6a13feb9c82803e2b815eca72fa7a9f5561d7861 appears later.
		# - git.gcommit(6a13feb9c82803e2b815eca72fa7a9f5561d7861).last_release_tag returns [v4.3, false]
		# - git.release_tag_order(v4.3) returns nil
		# refresh the cache to invalidate previous git object
		git = $git[project] = Git.open(project: project, working_dir: working_dir)
		version, is_exact_match = git.gcommit(commit).last_release_tag
		order = git.release_tag_order(version)

		# FIXME rli9 after above change, below situation is not reasonable, keep it for debugging purpose now
		unless order
			$stderr.puts "unknown version #{version} matrix: #{matrix_path} options: #{options}"
			return nil
		end
	end

	cols = 0
	git.release_tags_with_order.each { |tag, o|
		next if o >  order
		next if o == order and is_exact_match
		next if is_exact_match and tag =~ /^#{version}-rc[0-9]+$/
		break if tag =~ /\.[0-9]+$/ and tags_merged.size >= 2 and cols >= 10

		rp[axis] = tag
		base_matrix_file = rp._result_root + '/matrix.json'
		unless File.exist? base_matrix_file
			rp[axis] = git.release_tags2shas[tag]
			base_matrix_file = rp._result_root + '/matrix.json'
		end
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
		  (cols >= 1 and is_functional_test rp['testcase']) or
		  head_matrix['last_state.is_incomplete_run'] or
		  head_matrix['dmesg.boot_failures'] or
		  head_matrix['stderr.has_stderr']
			puts "compare with release matrix: #{matrix_path} #{tags_merged}" if ENV["LKP_VERBOSE"]
			options['good_commit'] = tags_merged.first
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

def __is_failure(stats_field)
	return false if stats_field.index('.time.')
	$metric_failure.each { |pattern| return true if stats_field =~ %r{^#{pattern}} }
	return false
end

def is_failure(stats_field)
	$__is_failure_cache ||= {}
	if $__is_failure_cache.include? stats_field
		$__is_failure_cache[stats_field]
	else
		$__is_failure_cache[stats_field] = __is_failure(stats_field)
	end
end

def __is_latency(stats_field)
	$metric_latency.each { |pattern| return true if stats_field =~ %r{^#{pattern}} }
	return false
end

def is_latency(stats_field)
	$__is_latency_cache ||= {}
	if $__is_latency_cache.include? stats_field
		$__is_latency_cache[stats_field]
	else
		$__is_latency_cache[stats_field] = __is_latency(stats_field)
	end
end

def is_memory_change(stats_field)
	stats_field =~ /^(boot-meminfo|boot-memory|proc-vmstat|numa-vmstat|meminfo|memmap|numa-meminfo)\./
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
def __get_changed_stats(a, b, is_incomplete_run, options)
	changed_stats = {}

	if options['regression-only']
		has_boot_fix = (b['last_state.booting'] && !a['last_state.booting'])
	else
		has_boot_fix = nil
	end

	resize = options['resize']

	cols_a = matrix_cols a
	cols_b = matrix_cols b

	if options['variance']
		return nil if cols_a < 10 or cols_b < 10
	end

	b_monitors = {}
	b.keys.each { |k| b_monitors[stat_to_monitor(k)] = true }

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

			# virtual hosts are dynamic and noisy
			next if options['tbox_group'] =~ /^vh-/
			# VM boxes' memory stats are still good
			next if options['tbox_group'] =~ /^vm-/ and !options['is_perf_test_vm'] and is_memory_change k
		end

		# newly added monitors don't have values to compare in the base matrix
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

		if options['regression-only']
			if is_failure_stat
				if max_a == 0
					has_boot_fix = true if k =~ /^dmesg\./
					next
				end
				# this relies on the fact dmesg.* comes ahead
				# of kmsg.* in etc/default_stats.yaml
				next if has_boot_fix and k =~ /^kmsg\./
			end
		end

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
		next unless is_reasonable_perf_change(k, delta, max)

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
		changed_stats[k].merge! options
	}

	return changed_stats
end

def load_matrices_to_compare(matrix_path1, matrix_path2, options = {})
	begin
		a = search_load_json matrix_path1
		return [nil, nil] unless a
		if matrix_path2
			b = search_load_json matrix_path2
		else
			b = load_base_matrix matrix_path1, a, options
		end
	rescue StandardError => e
		dump_exception(e, binding)
		return [nil, nil]
	end
	return [a, b]
end

def find_changed_stats(matrix_path, options)
	changed_stats = {}

	rp = ResultPath.new
	rp.parse_result_root matrix_path

	rp.each_commit do |commit_project, commit_axis|
		options['bisect_axis'] = commit_axis
		options['bisect_project'] = commit_project
		options['BAD_COMMIT'] = rp[commit_axis]

		puts options if ENV['LKP_VERBOSE']

		more_cs = get_changed_stats(matrix_path, nil, options)
		changed_stats.merge!(more_cs) if more_cs
	end

	changed_stats
end

def _get_changed_stats(a, b, options)
	is_incomplete_run =	a['last_state.is_incomplete_run'] ||
				b['last_state.is_incomplete_run']

	if is_incomplete_run and options['ignore-incomplete-run']
		changed_stats = {}
	else
		changed_stats = __get_changed_stats(a, b, is_incomplete_run, options)
		return changed_stats unless is_incomplete_run
	end

	# If reaches here, changed_stats only contains changed error ids.
	# Now remove incomplete runs to get any changed perf stats.
	filter_incomplete_run(a)
	filter_incomplete_run(b)

	is_all_incomplete_run =	(a['stats_source'].empty? ||
				 b['stats_source'].empty?)
	return changed_stats if is_all_incomplete_run

	more_changed_stats = __get_changed_stats(a, b, false, options)
	changed_stats.merge!(more_changed_stats) if more_changed_stats

	changed_stats
end

def get_changed_stats(matrix_path1, matrix_path2 = nil, options = {})
	unless matrix_path2 or options['bisect_axis']
		return find_changed_stats(matrix_path1, options)
	end

	a, b = load_matrices_to_compare matrix_path1, matrix_path2, options
	return nil if a == nil or b == nil

	_get_changed_stats(a, b, options)
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
			$stderr.puts "WARN: empty or non-exist stats file #{stats_file}"
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

def parse_stat_key(stat_key)
	stat_key.to_s.split('.')
end

def stat_key_base(stat_key)
	parse_stat_key(stat_key)[0]
end

def stat_to_monitor(stat)
	stat.partition('.').first
end

$kpi_stat_blacklist = Set.new [ 'vm-scalability.stddev' ]

def is_kpi_stat(stat, axes, values = nil)
	return false if $kpi_stat_blacklist.include?(stat)
	testcase = axes[TESTCASE_AXIS_KEY]
	stat.start_with?(testcase + '.') && !stat.start_with?(testcase + '.time')
end
