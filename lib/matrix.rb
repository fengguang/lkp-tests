#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

MAX_MATRIX_COLS = 100
STATS_SOURCE_KEY = 'stats_source'.freeze

require 'set'
require "#{LKP_SRC}/lib/log"
require "#{LKP_SRC}/lib/run-env"

def is_event_counter(name)
  $event_counter_prefixes ||= File.read("#{LKP_SRC}/etc/event-counter-prefixes").split
  $event_counter_prefixes.each do |prefix|
    return true if name.index(prefix) == 0
  end
  false
end

def is_independent_counter(name)
  $independent_counters ||= Set.new File.read("#{LKP_SRC}/etc/independent-counters").split
  $independent_counters.include? name
end

def max_cols(matrix)
  cols = 0
  matrix.each do |_k, v|
    cols = v.size if cols < v.size
  end
  cols
end

def matrix_fill_missing_zeros(matrix)
  cols = matrix['stats_source'].size
  matrix.each do |_k, v|
    v << 0 while v.size < cols
  end
  matrix
end

def add_performance_per_watt(stats, matrix)
  watt = stats['pmeter.Average_Active_Power']
  return unless watt && watt.positive?

  kpi_stats = load_yaml("#{LKP_SRC}/etc/index-perf.yaml")
  return unless kpi_stats

  performance = 0
  kpi_stats.each do |stat, weight|
    next if stat == 'boot-time.dhcp'
    next if stat == 'boot-time.boot'
    next if stat.index('iostat.') && !stats['dd.startup_time']

    value = stats[stat]
    next unless value
    if weight.negative?
      value = 1 / value
      weight = -weight
    end
    performance += value * weight
  end

  return unless performance.positive?

  stats['pmeter.performance_per_watt'] = performance / watt
  matrix['pmeter.performance_per_watt'] = [performance / watt]
end

def add_path_length(stats, matrix)
  workloads = stats.select { |s| s.end_with? '.workload' }
  return if workloads.size != 1
  instructions = stats['perf-stat.instructions']
  return unless instructions
  path_length = instructions.to_f / workloads.values[0]
  stats['perf-stat.path-length'] = path_length
  matrix['perf-stat.path-length'] = [path_length]
end

def create_stats_matrix(result_root)
  stats = {}
  matrix = {}

  create_programs_hash 'stats/**/*'
  monitor_files = Dir["#{result_root}/*.{json,json.gz}"]

  monitor_files.each do |file|
    next unless File.size?(file)

    case file
    when /\.json$/
      monitor = File.basename(file, '.json')
    when /\.json\.gz$/
      monitor = File.basename(file, '.json.gz')
    end

    next if monitor == 'stats' # stats.json already created?
    next if monitor == 'matrix'
    unless $programs[monitor] || monitor =~ /^ftrace\.|.+\.time$/
      log_warn "skip unite #{file}: #{monitor} not in #{$programs.keys}"
      next
    end

    monitor_stats = load_json file
    sample_size = max_cols(monitor_stats)
    monitor_stats.each do |k, v|
      next if k == "#{monitor}.time"
      stats[k] = if v.size == 1
                   v[0]
                 elsif is_independent_counter k
                   v.sum
                 elsif is_event_counter k
                   v[-1] - v[0]
                 else
                   v.sum / sample_size
                 end
      stats[k + '.max'] = v.max if should_add_max_latency k
    end
    matrix.merge! monitor_stats
  end

  add_performance_per_watt(stats, matrix)
  add_path_length(stats, matrix)
  save_json(stats, result_root + '/stats.json')
  save_json(matrix, result_root + '/matrix.json', true)
  if local_run?
    save_matrix_to_csv_file(result_root + '/stats.csv', stats)
    save_matrix_to_csv_file(result_root + '/matrix.csv', matrix)
  end
  stats
end

def load_create_stats_matrix(result_root)
  stats_file = result_root + '/stats.json'
  if File.exist? stats_file
    load_json stats_file
  else
    create_stats_matrix result_root
  end
end

def matrix_average(matrix)
  avg = {}
  matrix.each { |k, v| avg[k] = v.empty? ? 0 : v.average }
  avg
end

def matrix_stddev(matrix)
  stddev = {}
  matrix.each { |k, v| stddev[k] = v.empty? ? 0 : v.standard_deviation }
  stddev
end

def load_matrix_file(matrix_file)
  matrix = nil
  begin
    matrix = load_json(matrix_file) if File.exist? matrix_file
  rescue StandardError
    return nil
  end
  matrix
end

def shrink_matrix(matrix, max_cols)
  n = matrix['stats_source'].size - max_cols
  return unless n > 1

  empty_keys = []
  matrix.each do |k, v|
    v.shift n
    empty_keys << k if v.empty?
  end
  empty_keys.each { |k| matrix.delete k }
end

def matrix_delete_col(matrix, col)
  matrix.each do |_k, v|
    v.delete_at col
  end
end

def unite_remove_blacklist_stats(matrix)
  # sched_debug per-cpu stats usually change a lot among multiple running,
  # still keep statistic stats such as avg, min, max, stddev, etc.
  matrix.reject do |k, _v|
    k =~ /^sched_debug.*\.[0-9]+$/
  end
end

def unite_to(stats, matrix_root, max_cols = nil, delete = false)
  matrix_file = matrix_root + '/matrix.json'

  matrix = load_matrix_file(matrix_root + '/matrix.json')
  matrix ||= load_matrix_file(matrix_root + '/matrix.yaml')

  if matrix
    dup_col = matrix[STATS_SOURCE_KEY].index stats[STATS_SOURCE_KEY]
    matrix_delete_col(matrix, dup_col) if dup_col
  else
    matrix = {}
  end

  matrix = add_stats_to_matrix(stats, matrix) unless delete
  shrink_matrix(matrix, max_cols) if max_cols

  matrix = unite_remove_blacklist_stats(matrix)
  save_json(matrix, matrix_file)
  matrix = matrix_fill_missing_zeros(matrix)
  save_matrix_to_csv_file(matrix_root + '/matrix.csv', matrix) if local_run?
  matrix.delete 'stats_source'
  begin
    avg = matrix_average(matrix)
    stddev = matrix_stddev(matrix)
    save_json(avg, matrix_root + '/avg.json')
    save_json(stddev, matrix_root + '/stddev.json')
    if local_run?
      save_matrix_to_csv_file(matrix_root + '/avg.csv', avg)
      save_matrix_to_csv_file(matrix_root + '/stddev.csv', stddev)
    end
  rescue TypeError
    log_error "matrix contains non-number values, move to #{matrix_file}-bad"
    FileUtils.mv matrix_file, matrix_file + '-bad', force: true # never raises exception
  end
  matrix
end

# serves as locate db
def save_paths(result_root, user)
  FileUtils.mkdir_p '/lkp/paths'
  paths_file = "/lkp/paths/#{Time.now.strftime('%F')}-#{user}"

  # to avoid confusing between .../1 and .../11, etc. when search/remove, etc.
  result_root += '/' unless result_root.end_with?('/')

  File.open(paths_file, 'a') do |f|
    f.puts(result_root)
  end
end

def merge_matrixes(matrixes)
  mresult = {}
  matrixes.each do |m|
    add_stats_to_matrix(m, mresult)
  end
  mresult
end

def check_warn_test_error(matrix, _result_root)
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
    next if errid == 'last_state.is_incomplete_run' && matrix['dmesg.boot_failures']
    # $stderr.puts "The last 10 results all failed, check: #{errid} #{result_root}"
  end
end

def sort_matrix(matrix, key)
  key_index = matrix.keys.index key
  t = matrix.values.transpose
  t.sort_by! do |vs|
    vs[key_index]
  end
  values = t.transpose
  m = {}
  matrix.keys.each_with_index do |k, i|
    m[k] = values[i]
  end
  m
end

def save_matrix_as_csv(file, matrix, sep = ' ', _header = true, fill = -1)
  fill && cols = matrix.map { |_k, v| v.size }.max
  matrix.each do |k, vs|
    vs = Array vs
    fill && vs += [fill] * (cols - vs.size)
    fields = [k] + vs.map(&:to_s)
    file.puts fields.join(sep)
  end
end

def save_matrix_to_csv_file(file_name, matrix, sep = ',', header = true)
  File.open(file_name, 'w') do |f|
    save_matrix_as_csv(f, matrix, sep, header, nil)
  end
end

def print_matrix(matrix)
  ks = matrix.map { |k, _vs| k.size }.max
  matrix.each do |k, vs|
    printf "%-#{ks}s ", k
    vs.each do |v|
      s = format_number(v)
      printf '%-12s', s
    end
    puts
  end
end

def unite_params(result_root)
  unless File.directory? result_root
    log_error "#{result_root} is not a directory"
    return false
  end

  result_path = ResultPath.new
  result_path.parse_result_root result_root

  params_file = result_path.params_file
  params_root = File.dirname params_file

  if File.exist?(params_file) && Time.now - File.ctime(params_root) > 3600
    # no need to update params
    return true
  end

  params = {}
  params = YAML.load_file(params_file) if File.exist? params_file

  job = Job.new
  begin
    job.load(result_root + '/job.yaml')
  rescue StandardError
    return
  end

  job.each_param do |k, v, _option_type|
    if params[k]
      params[k] << v unless params[k].include? v
    else
      params[k] = [v]
    end
  end

  begin
    atomic_save_yaml_json params, params_file
  rescue StandardError => e
    log_exception e, binding
  end
end

def unite_stats(result_root, delete = false)
  unless File.directory? result_root
    log_error "#{result_root} is not a directory"
    return false
  end

  result_root = File.realpath result_root
  _result_root = File.dirname result_root
  __result_root = File.dirname _result_root

  stats = load_create_stats_matrix result_root

  return false if stats.nil?

  stats['stats_source'] = result_root + '/stats.json'

  unite_to(stats, _result_root, nil, delete)
  begin
    __matrix = unite_to(stats, __result_root, 100, delete)
    check_warn_test_error __matrix, result_root
  rescue StandardError => e
    log_warn e.formatted_headline
  end

  true
end
