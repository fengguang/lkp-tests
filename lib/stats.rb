#!/usr/bin/env ruby

MARGIN_SHIFT = 5
MAX_RATIO = 5

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'set.rb'
require "#{LKP_SRC}/lib/lkp_git"
require "#{LKP_SRC}/lib/git-update.rb" if File.exist?("#{LKP_SRC}/lib/git-update.rb")
require "#{LKP_SRC}/lib/yaml.rb"
require "#{LKP_SRC}/lib/result.rb"
require "#{LKP_SRC}/lib/bounds.rb"
require "#{LKP_SRC}/lib/constant.rb"
require "#{LKP_SRC}/lib/statistics.rb"
require "#{LKP_SRC}/lib/log"
require "#{LKP_SRC}/lib/tests.rb"
require "#{LKP_SRC}/lib/nresult_root"

$metric_add_max_latency = IO.read("#{LKP_SRC}/etc/add-max-latency").split("\n")
$metric_latency = IO.read("#{LKP_SRC}/etc/latency").split("\n")
$metric_failure = IO.read("#{LKP_SRC}/etc/failure").split("\n")
$perf_metrics_threshold = YAML.load_file "#{LKP_SRC}/etc/perf-metrics-threshold.yaml"
$perf_metrics_prefixes = File.read("#{LKP_SRC}/etc/perf-metrics-prefixes").split
$index_perf = load_yaml "#{LKP_SRC}/etc/index-perf.yaml"

$perf_metrics_re = load_regular_expressions("#{LKP_SRC}/etc/perf-metrics-patterns")
$metrics_blacklist_re = load_regular_expressions("#{LKP_SRC}/etc/blacklist")
$kill_pattern_whitelist_re = load_regular_expressions("#{LKP_SRC}/etc/dmesg-kill-pattern")

# => ["tcrypt.", "hackbench.", "dd.", "xfstests.", "aim7.", ..., "oltp.", "fileio.", "dmesg."]
def test_prefixes
  stats = Dir["#{LKP_SRC}/stats/**/*"].map { |path| File.basename path }
  tests = Dir["#{LKP_SRC}/{tests,daemon}/**/*"].map { |path| File.basename path }
  tests = stats & tests
  tests.delete 'wrapper'
  tests.push 'kmsg'
  tests.push 'dmesg'
  tests.push 'stderr'
  tests.push 'last_state'
  tests.map { |test| test + '.' }
end

def is_functional_test(testcase)
  MResultRootTableSet::LINUX_TESTCASES.index testcase
end

def other_test?(testcase)
  MResultRootTableSet::OTHER_TESTCASES.index testcase
end

$test_prefixes = test_prefixes
$perf_metrics_prefixes.concat($test_prefixes.reject { |test| is_functional_test(test[0..-2]) || other_test?(test[0..-2]) })

def __is_perf_metric(name)
  return true if name =~ $perf_metrics_re

  $perf_metrics_prefixes.each do |prefix|
    return true if name.index(prefix) == 0
  end

  false
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
  $perf_metrics_threshold.each do |k, v|
    next unless name =~ %r{^#{k}$}
    return false if max < v
    return false if delta < v / 2 && v.class == Integer
    return true
  end

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
      return delta > 10_000
    when 'holdtime-total'
      return delta > 100_000
    when /time/
      return delta > 1_000
    else
      return delta > 10_000
    end
  when /^interrupts/, /^softirqs/
    return max > 10_000
  end
  true
end

def is_changed_stats(sorted_a, min_a, mean_a, max_a,
                     sorted_b, min_b, mean_b, max_b,
                     is_failure_stat, is_latency_stat,
                     stat, options)

  if options['perf-profile'] && stat =~ /^perf-profile\./ && options['perf-profile'].is_a?(mean_a.class)
    return mean_a > options['perf-profile'] ||
           mean_b > options['perf-profile']
  end

  return max_a != max_b if is_failure_stat

  if is_latency_stat
    if options['distance']
      # auto start bisect only for big regression
      return false if sorted_b.size <= 3 && sorted_a.size <= 3
      return false if sorted_b.size <= 3 && min_a < 2 * options['distance'] * max_b
      return false if max_a < 2 * options['distance'] * max_b
      return false if mean_a < options['distance'] * max_b
      return true
    elsif options['gap']
      gap = options['gap']
      return true if min_b > max_a && (min_b - max_a) > (mean_b - mean_a) * gap
      return true if min_a > max_b && (min_a - max_b) > (mean_a - mean_b) * gap
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
    return false if max_a.is_a?(Integer) && (min_a - max_b == 1 || min_b - max_a == 1)
    if sorted_a.size < 3 || sorted_b.size < 3
      min_gap = [len_a, len_b].max * options['distance']
      return true if min_b - max_a > min_gap
      return true if min_a - max_b > min_gap
      return false
    end
    return true if min_b > max_a && (min_b - max_a) > (mean_b - mean_a) / 2
    return true if min_a > max_b && (min_a - max_b) > (mean_a - mean_b) / 2
  elsif options['gap']
    gap = options['gap']
    return true if min_b > max_a && (min_b - max_a) > (mean_b - mean_a) * gap
    return true if min_a > max_b && (min_a - max_b) > (mean_a - mean_b) * gap
  else
    return true if min_b > mean_a && mean_b > max_a
    return true if min_a > mean_b && mean_a > max_b
  end
  false
end

# sort key for reporting all changed stats
def stat_relevance(record)
  stat = record['stat']
  relevance = if stat[0..9] == 'lock_stat.'
                5
              elsif $test_prefixes.include? stat.sub(/\..*/, '.')
                100
              elsif is_perf_metric(stat)
                1
              else
                10
              end
  [relevance, [record['ratio'], 5].min]
end

def sort_stats(stat_records)
  stat_records.keys.sort_by do |stat|
    order1 = 0
    order2 = 0.0
    stat_records[stat].each do |record|
      key = stat_relevance(record)
      order1 = key[0]
      order2 += key[1]
    end
    order2 /= $stat_records[stat].size
    - order1 - order2
  end
end

def matrix_cols(hash_of_array)
  if hash_of_array.nil?
    0
  elsif hash_of_array.empty?
    0
  elsif hash_of_array['stats_source']
    hash_of_array['stats_source'].size
  else
    [hash_of_array.values[0].size, hash_of_array.values[-1].size].max
  end
end

def load_release_matrix(matrix_file)
  load_json matrix_file
rescue => e
  log_exception e, binding
  nil
end

def vmlinuz_dir(kconfig, compiler, commit)
  "#{KERNEL_ROOT}/#{kconfig}/#{compiler}/#{commit}"
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

  begin
    $git ||= {}
    axis_branch_name =
      if axis == 'commit'
        options['branch']
      else
        options[axis.sub('commit', 'branch')]
      end
    remote = axis_branch_name.split('/')[0] if axis_branch_name

    log_debug "remote is #{remote}"
    $git[project] ||= Git.open(project: project, remote: remote)
    git = $git[project]
  rescue => e
    log_exception e, binding
    return nil
  end

  begin
    return nil unless git.commit_exist? commit
    version, is_exact_match = git.gcommit(commit).last_release_tag
    puts "project: #{project}, version: #{version}, is exact match: #{is_exact_match}" if ENV['LKP_VERBOSE']
  rescue StandardError => e
    log_exception e, binding
    return nil
  end

  # FIXME: remove it later; or move it somewhere in future
  if project == 'linux' && !version
    kconfig = rp['kconfig']
    compiler = rp['compiler']
    context_file = vmlinuz_dir(kconfig, compiler, commit) + '/context.yaml'
    version = nil
    if File.exist? context_file
      context = YAML.load_file context_file
      version = context['rc_tag']
      is_exact_match = false
    end
    unless version
      log_error "Cannot get base RC commit for #{commit}"
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
    git = $git[project] = Git.open(project: project)
    version, is_exact_match = git.gcommit(commit).last_release_tag
    order = git.release_tag_order(version)

    # FIXME: rli9 after above change, below situation is not reasonable, keep it for debugging purpose now
    unless order
      log_error "unknown version #{version} matrix: #{matrix_path} options: #{options}"
      return nil
    end
  end

  cols = 0
  git.release_tags_with_order.each do |tag, o|
    next if o >  order
    next if o == order && is_exact_match
    next if is_exact_match && tag =~ /^#{version}-rc[0-9]+$/
    break if tag =~ /\.[0-9]+$/ && tags_merged.size >= 2 && cols >= 10

    rp[axis] = tag
    base_matrix_file = rp._result_root + '/matrix.json'
    unless File.exist? base_matrix_file
      rp[axis] = git.release_tags2shas[tag]
      base_matrix_file = rp._result_root + '/matrix.json'
    end
    next unless File.exist? base_matrix_file

    log_debug "base_matrix_file: #{base_matrix_file}"
    rc_matrix = load_release_matrix base_matrix_file
    next unless rc_matrix
    add_stats_to_matrix(rc_matrix, matrix)
    tags_merged << tag
    cols += matrix['stats_source'].size
    break if tags_merged.size >= 3 && cols >= 20
    break if tag =~ /-rc1$/ && cols >= 3
  end

  if !matrix.empty?
    if cols >= 3 ||
       (cols >= 1 && is_functional_test(rp['testcase'])) ||
       head_matrix['last_state.is_incomplete_run'] ||
       head_matrix['dmesg.boot_failures'] ||
       head_matrix['stderr.has_stderr']
      log_debug "compare with release matrix: #{matrix_path} #{tags_merged}"
      options['good_commit'] = tags_merged.first
      return matrix
    else
      log_debug "release matrix too small: #{matrix_path} #{tags_merged}"
      return nil
    end
  else
    log_debug "no release matrix was found: #{matrix_path}"
    return nil
  end
end

def __is_failure(stats_field)
  return false if stats_field.index('.time.')
  return false if stats_field.index('.timestamp.')
  $metric_failure.each { |pattern| return true if stats_field =~ %r{^#{pattern}} }
  false
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
  false
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
  false
end

def sort_remove_margin(array, max_margin = nil)
  return nil unless array

  margin = array.size >> MARGIN_SHIFT
  margin = [margin, max_margin].min if max_margin

  array = array.sorted
  array[margin..-margin - 1]
end

# NOTE: array *must* be sorted
def get_min_mean_max(array)
  return [0, 0, 0] unless array

  [array[0], array[array.size / 2], array[-1]]
end

# Filter out data generated by incomplete run
def filter_incomplete_run(hash)
  is_incomplete_runs = hash['last_state.is_incomplete_run']
  return unless is_incomplete_runs

  delete_index_list = []
  is_incomplete_runs.each_with_index do |val, index|
    delete_index_list << index if val == 1
  end
  delete_index_list.reverse!

  hash.each do |_k, v|
    delete_index_list.each do |index|
      v.delete_at(index)
    end
  end

  hash.delete 'last_state.is_incomplete_run'
end

# b is the base of compare (eg. rc kernels) and normally have more samples than
# a (eg. the branch HEADs)
def __get_changed_stats(a, b, is_incomplete_run, options)
  changed_stats = {}

  has_boot_fix = if options['regression-only'] || options['all-critical']
                   (b['last_state.booting'] && !a['last_state.booting'])
                 end

  resize = options['resize']

  cols_a = matrix_cols a
  cols_b = matrix_cols b

  if options['variance']
    return nil if cols_a < 10 || cols_b < 10
  end

  b_monitors = {}
  b.keys.each { |k| b_monitors[stat_key_base(k)] = true }

  b.keys.each { |k| a[k] = [0] * cols_a unless a.include?(k) }

  a.each do |k, v|
    next if v[-1].is_a?(String)
    next if options['perf'] && !is_perf_metric(k)
    next if is_incomplete_run && k !~ /^(dmesg|last_state|stderr)\./
    next if !options['more'] && k =~ $metrics_blacklist_re

    is_failure_stat = is_failure k
    is_latency_stat = is_latency k
    max_margin = if is_failure_stat || is_latency_stat
                   0
                 else
                   3
                 end

    unless is_failure_stat
      # for none-failure stats field, we need asure that
      # at least one matrix has 3 samples.
      next if cols_a < 3 && cols_b < 3 && !options['whole']

      # virtual hosts are dynamic and noisy
      next if options['tbox_group'] =~ /^vh-/
      # VM boxes' memory stats are still good
      next if options['tbox_group'] =~ /^vm-/ && !options['is_perf_test_vm'] && is_memory_change(k)
    end

    # newly added monitors don't have values to compare in the base matrix
    next unless b[k] ||
                is_failure_stat ||
                (k =~ /^(lock_stat|perf-profile|latency_stats)\./ && b_monitors[$1])

    b_k = b[k] || [0] * cols_b
    b_k << 0 while b_k.size < cols_b
    v << 0 while v.size < cols_a

    sorted_b = sort_remove_margin b_k, max_margin
    min_b, mean_b, max_b = get_min_mean_max sorted_b
    next unless max_b

    v.pop(v.size - resize) if resize && v.size > resize

    max_margin = 1 if b_k.size <= 3 && max_margin > 1
    sorted_a = sort_remove_margin v, max_margin
    min_a, mean_a, max_a = get_min_mean_max sorted_a
    next unless max_a

    next unless is_changed_stats(sorted_a, min_a, mean_a, max_a,
                                 sorted_b, min_b, mean_b, max_b,
                                 is_failure_stat, is_latency_stat,
                                 k, options)

    if options['regression-only'] || options['all-critical']
      if is_failure_stat
        if max_a.zero?
          has_boot_fix = true if k =~ /^dmesg\./
          next if options['regression-only'] ||
                  (k !~ $kill_pattern_whitelist_re && options['all-critical'])
        end
        # this relies on the fact dmesg.* comes ahead
        # of kmsg.* in etc/default_stats.yaml
        next if has_boot_fix && k =~ /^kmsg\./
      end
    end

    max = [max_b, max_a].max
    x = max_a - min_a
    z = max_b - min_b
    x = z if sorted_a.size <= 2 && x < z
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

    unless options['perf-profile'] && k =~ /^perf-profile\./
      next unless ratio > 1.01 # time.elapsed_time only has 0.01s precision
      next unless ratio > 1.1 || is_perf_metric(k)
      next unless is_reasonable_perf_change(k, delta, max)
    end

    interval_a = format('[ %-10.5g - %-10.5g ]', min_a, max_a)
    interval_b = format('[ %-10.5g - %-10.5g ]', min_b, max_b)
    interval = interval_a + ' -- ' + interval_b

    changed_stats[k] = { 'stat' => k,
                         'interval' => interval,
                         'a' => sorted_a,
                         'b' => sorted_b,
                         'ttl' => Time.now,
                         'is_failure' => is_failure_stat,
                         'is_latency' => is_latency_stat,
                         'ratio' => ratio,
                         'delta' => delta,
                         'mean_a' => mean_a,
                         'mean_b' => mean_b,
                         'x' => x,
                         'y' => y,
                         'z' => z,
                         'min_a' => min_a,
                         'max_a' => max_a,
                         'min_b' => min_b,
                         'max_b' => max_b,
                         'max' => max,
                         'nr_run' => v.size }
    changed_stats[k].merge! options
  end

  changed_stats
end

def load_matrices_to_compare(matrix_path1, matrix_path2, options = {})
  begin
    a = search_load_json matrix_path1
    return [nil, nil] unless a
    b = if matrix_path2
          search_load_json matrix_path2
        else
          load_base_matrix matrix_path1, a, options
         end
  rescue StandardError => e
    log_exception(e, binding)
    return [nil, nil]
  end
  [a, b]
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
  is_incomplete_run = a['last_state.is_incomplete_run'] ||
                      b['last_state.is_incomplete_run']

  if is_incomplete_run && options['ignore-incomplete-run']
    changed_stats = {}
  else
    changed_stats = __get_changed_stats(a, b, is_incomplete_run, options)
    return changed_stats unless is_incomplete_run
  end

  # If reaches here, changed_stats only contains changed error ids.
  # Now remove incomplete runs to get any changed perf stats.
  filter_incomplete_run(a)
  filter_incomplete_run(b)

  is_all_incomplete_run = (a['stats_source'].empty? ||
         b['stats_source'].empty?)
  return changed_stats if is_all_incomplete_run

  more_changed_stats = __get_changed_stats(a, b, false, options)
  changed_stats.merge!(more_changed_stats) if more_changed_stats

  changed_stats
end

def get_changed_stats(matrix_path1, matrix_path2 = nil, options = {})
  unless matrix_path2 || options['bisect_axis']
    return find_changed_stats(matrix_path1, options)
  end

  a, b = load_matrices_to_compare matrix_path1, matrix_path2, options
  return nil if a.nil? || b.nil?

  _get_changed_stats(a, b, options)
end

def add_stats_to_matrix(stats, matrix)
  columns = 0
  matrix.each { |_k, v| columns = v.size if columns < v.size }
  stats.each do |k, v|
    matrix[k] ||= []
    matrix[k] << 0 while matrix[k].size < columns
    if v.is_a?(Array)
      matrix[k].concat v
    else
      matrix[k] << v
    end
  end
  matrix
end

def matrix_from_stats_files(stats_files, add_source = true)
  matrix = {}
  stats_files.each do |stats_file|
    stats = load_json stats_file
    unless stats
      log_warn "empty or non-exist stats file #{stats_file}"
      next
    end
    stats['stats_source'] ||= stats_file if add_source
    matrix = add_stats_to_matrix(stats, matrix)
  end
  matrix
end

def samples_fill_missing_zeros(matrix, key)
  size = matrix_cols matrix
  samples = matrix[key] || [0] * size
  samples << 0 while samples.size < size
  samples
end

def stat_key_base(stat)
  stat.partition('.').first
end

def is_kpi_stat_strict(stat, _axes, _values = nil)
  $index_perf.include? stat
end

$kpi_stat_blacklist = Set.new ['vm-scalability.stddev', 'unixbench.incomplete_result']

def is_kpi_stat(stat, _axes, _values = nil)
  return false if $kpi_stat_blacklist.include?(stat)
  base, _, remainder = stat.partition('.')
  all_tests_set.include?(base) && !remainder.start_with?('time.')
end

def kpi_stat_direction(stat_name, stat_change_percentage)
  change_direction = 'improvement'

  if $index_perf[stat_name] && $index_perf[stat_name] * stat_change_percentage < 0
    change_direction = 'regression'
  end
  change_direction
end
