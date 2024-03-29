#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require "#{LKP_SRC}/lib/run_env"
require "#{LKP_SRC}/lib/common"
require "#{LKP_SRC}/lib/result"
require "#{LKP_SRC}/lib/constant"
require "#{LKP_SRC}/lib/hash"
require "#{LKP_SRC}/lib/erb"
require "#{LKP_SRC}/lib/log"
require 'fileutils'
require 'yaml'
require 'json'
require 'set'
require 'pp'
require 'English'

def restore(ah, copy)
  if ah.instance_of?(Hash)
    ah.clear.merge!(copy)
  elsif ah.instance_of?(Array)
    ah.clear.concat(copy)
  end
end

def expand_shell_var(env, o)
  s = o.to_s
  return s unless local_run?

  if s.index('$')
    f = IO.popen(env, ['/bin/bash', '-c', "eval echo \"#{s}\""], 'r')
    s = f.read.chomp
    f.close
  elsif s.index('/dev/disk/')
    files = {}
    s.split.each do |f|
      Dir.glob(f).each { |d| files[File.realpath d] = d }
    end
    s = files.keys.sort_by do |dev|
      dev =~ /(\d+)$/
      $1.to_i
    end.join ' '
  end
  s
end

def expand_toplevel_vars(env, hash)
  vars = {}
  hash.each do |key, val|
    next unless key.is_a?(String)

    case val
    when Hash
      vars[key] = expand_shell_var(env, val) if %w[disk boot_params].include? key
      next
    when nil
      vars[key] = nil
    when Array
      vars[key] = expand_shell_var(env, val[0]) if val.size == 1
    else
      vars[key] = expand_shell_var(env, val)
    end
  end
  vars
end

def string_or_hash_key(h)
  if h.instance_of?(Hash)
    # assert h.size == 1
    h.keys[0]
  else
    h
  end
end

# if match return k or re_k
def string_re_hash_key(hash, re_k, exist=nil)
  exist ||= []
  hash.keys.each do |k|
    return k if k.is_a?(String) && !exist.include?(k) && re_k =~ /^#{k}(-\d+){0,1}$/
  end
  re_k
end

# if match return key or nil
def hash_key_re_string(hash, re_k, exist=nil)
  exist ||= []
  hash.keys.each do |k|
    return k if k.is_a?(String) && !exist.include?(k) && k =~ /^#{re_k}(-\d+){0,1}$/
  end
  nil
end

def for_each_in(ah, set, pk = nil)
  ah.each do |k, v|
    next if k == 'pp' || k == 'ss'

    k = k.sub(/-\d+$/, '') if k.is_a?(String)
    yield pk, ah, k, v if set.include?(k)
    next unless v.is_a?(Hash)

    for_each_in(v, set, k) do |pk, h, k, v|
      yield pk, h, k, v
    end
  end
end

# programs[script] = full/path/to/script
def __create_programs_hash(glob, lkp_src)
  programs = {}
  Dir.glob("#{lkp_src}/#{glob}").each do |path|
    next if File.directory?(path)
    next if path =~ /\.yaml$/
    next if path =~ /\.[0-9]+$/

    unless File.executable?(path)
      if File.symlink?(path)
        real_path = File.readlink(path)
        real_path = File.join(File.dirname(path), real_path) if real_path =~ /^\.\.|^\w/
        next unless File.exist?(real_path)
      end
      log_warn "skip non-executable #{path}" unless path =~ /\.cr$/
      next
    end
    file = File.basename(path)
    next if file == 'wrapper'

    if programs.include? file
      log_error "Conflict names #{programs[file]} and #{path}"
      next
    end
    programs[file] = path
  end
  programs
end

def create_programs_hash(glob, lkp_src = LKP_SRC)
  cache_key = [glob, lkp_src].join ':'
  $programs_cache ||= {}
  $programs =
    $programs_cache[cache_key] ||= __create_programs_hash(glob, lkp_src).freeze
end

def atomic_save_yaml_json(object, file)
  temp_file = file + "-#{tmpname}"
  File.open(temp_file, 'w') do |file|
    if temp_file.index('.json')
      lines = JSON.pretty_generate(object, allow_nan: true)
    else
      lines = YAML.dump(object)
      # create comment lines from symbols
      lines.gsub!(/^:#(.*): $/, "\n#\\1")
      lines.gsub!(/^\? :#(.*)\n: $/, "\n#\\1")
    end
    file.write(lines)
  end
  FileUtils.mv temp_file, file, force: true
end

def rootfs_filename(rootfs)
  rootfs.split(/[^a-zA-Z0-9._-]/)[-1]
end

def comment_to_symbol(str)
  :"#! #{str}"
end

def replace_symbol_keys(hash)
  return hash unless hash.is_a?(Hash)

  sh = {}
  hash.each do |k, v|
    sh[k.to_s] = v
  end
  sh
end

def read_param_map_rules(file)
  lines = File.read file
  rules = {}
  prev_rule = nil
  head = nil
  loop do
    head, rule, lines = lines.partition(/^\/(.*?[^\\])\/\s+/)
    head.chomp!
    rules[prev_rule] = head if prev_rule
    break if rule.empty?

    prev_rule = Regexp.new $1
  end
  rules[prev_rule] = head if prev_rule
  rules
end

class JobFileSyntaxError < RuntimeError
  def initialize(jobfile, syn_msg)
    @jobfile = jobfile
    super "Jobfile: #{jobfile}, syntax error: #{syn_msg}"
  end

  attr_reader :jobfile
end

class Job
  class ParamError < ArgumentError
  end

  class SyntaxError < ArgumentError
  end
end

class Job
  EXPAND_DIMS = %w(kconfig commit rootfs ltp_commit nvml_commit blktests_commit qemu_commit perf_test_commit linux_commit).freeze

  attr_reader :path_scheme
  attr_reader :referenced_programs
  attr_accessor :overrides
  attr_accessor :defaults
  attr_accessor :cmdline_defaults
  attr_accessor :default_yamls
  attr_accessor :override_yamls

  def initialize(job = {}, defaults = {}, overrides = {}, cmdline_defaults={})
    @job = job
    @defaults = defaults # from auto includes
    @overrides = overrides # from command line
    @cmdline_defaults = cmdline_defaults # from command line
    @available_programs = {}
    @default_yamls = []
    @override_yamls = []
  end

  def source_file_symkey(file)
    comment_to_symbol file.sub("#{lkp_src}/", '')
  end

  def load(jobfile, expand_template = false)
    yaml = File.read jobfile
    # give a chance
    if yaml.size.zero? && !File.size(jobfile).zero?
      log_error "start reload #{jobfile}"
      yaml = File.read jobfile
      if yaml.size.zero?
        log_error "reload #{jobfile} failed"
      else
        log_error "reload #{jobfile} succeed"
      end
    end
    raise ArgumentError, "empty jobfile #{jobfile}" if yaml.empty?

    # keep comment lines as symbols
    yaml.gsub!(/\n\n#([! ][-a-zA-Z0-9 !|\/?@<>.,_+=%~]+)$/, "\n:#\\1: ")

    begin
      yaml = expand_yaml_template(yaml, jobfile) if expand_template

      @jobs = []
      YAML.load_stream(yaml) do |hash|
        if hash.has_key?('override') && hash['override'].is_a?(Hash)
          @overrides.merge!(hash['override']){ |_key, a, _b| a}
          hash.delete('override')
        end

        if hash.has_key?('id')
          d_keys = ["my_name", "my_email", "my_account", "lab"]
          hash.delete_if { |k| d_keys.include? k }
        end

        revise_hash(hash, load_include_yamls(@default_yamls), false) unless @default_yamls.empty?
        revise_hash(hash, load_include_yamls(@override_yamls), true) unless @override_yamls.empty?
        revise_hash(hash, @overrides, true) unless @overrides.empty?

        hash.delete_if { |key, _| key.is_a?(String) && key.start_with?('#!') }
        @jobs.concat(multi_args(hash)) # return [hash] or [h1,h2]
      end
    rescue StandardError => e
      log_error "#{jobfile}: " + e.message
      raise
    end

    @job = {}
    unless @jobs.first['job_origin']
      if File.symlink?(jobfile) &&
        File.readlink(jobfile) =~ %r|^../../../(.*)|
        @job[comment_to_symbol $1] = nil
      else
        jobfile = File.realpath(jobfile)
        job_path = File.dirname(jobfile)
        if job_path.start_with?(LKP_SRC)
          prefix = LKP_SRC
        else
          prefix = `git -C "#{job_path}" rev-parse --show-toplevel 2>/dev/null`.chomp
          prefix = ENV['HOME'] if prefix.empty?
        end
        jobfile.sub!(/^#{prefix}\//, "")
        @job[source_file_symkey jobfile] = nil
      end
    end
    @job.merge!(@jobs.shift)
    @job['job_origin'] ||= jobfile
    @jobfile = jobfile
  end

  def load_include_yamls(include_yamls)
    include_hash = {}
    include_hash[comment_to_symbol("#{include_yamls.join(' ')}")] = nil
    include_hash.merge!(load_yaml_merge(include_yamls, {}))
  end

  def split_multi_args(value)
    if value =~ /^\w.*\|.*\w$/
      return value.split('|').map(&:strip)
    elsif value =~ /^\w.*\:.*\w$/
      return value.split(':').map(&:strip)
    else
      return false
    end
  end

  def multi_args(hash)
    jobs_array = [hash.clone]
    hash.each do |key, value|
      next unless key.is_a?(String)

      if key =~ /^\w.*[\:|\|].*\w$/
        jobs_array = load_join_args(jobs_array, key, value)
      end
    end

    hash.each do |key, value|
      next unless key.is_a?(String)

      if %w(testbox tbox_group os os_arch os_version arch os_mount).include?(key) && value.is_a?(Array)
        jobs_array = load_array_args(jobs_array, key, value)
      end
    end
    return jobs_array
  end

  def load_array_args(jobs_array, key, value)
    _jobs_array = []

    jobs_array.each do |job_hash|
      value.each do |v|
        _job_hash = job_hash.clone
        _job_hash[key] = v
        @overrides.delete(key)
        _jobs_array << _job_hash
      end
    end
    return _jobs_array
  end

  def load_join_args(jobs_array, key, value)
    _jobs_array = []

    jobs_array.each do |job_hash|
      key_array = split_multi_args(key)

      [value].flatten.each do |value|
        value_array = split_multi_args(value)
        break unless value_array
        break unless key_array.size == value_array.size

        _job_hash = job_hash.clone
        key_array.size.times do |i|
          _job_hash[key_array[i]] = value_array[i]
        end

        _job_hash.delete(key)
        @overrides.delete(key)
        _jobs_array << _job_hash
      end
    end
    _jobs_array = jobs_array if _jobs_array.empty?
    return _jobs_array
  end

  def delete_keys_from_spec(spec_file)
    return unless File.exist? spec_file

    spec_file_context = load_yaml(spec_file, nil)
    spec_file_context.each_key { |k| @job.delete k }
  end

  def load_hosts_config
    return if @job.include?(:no_defaults)

    check_set_tbox_group
    hosts_file = get_hosts_file
    if hosts_file
      hwconfig = load_yaml(hosts_file, {})
      @job[source_file_symkey(hosts_file)] = nil
      @job.merge!(hwconfig) { |_k, a, _b| a } # job's key/value has priority over hwconfig
    end

    @job['os_arch'] ||= 'aarch64'
    @job['arch'] ||= @job['os_arch']
  end

  def check_set_tbox_group
    unless @job.include?('testbox')
      @job[comment_to_symbol('set default testbox')] = nil
      @job['testbox'] = 'dc-8g'
    end
    @job['tbox_group'] = tbox_group(@job['testbox'])
  end

  def get_hosts_file
    lab_repo = "#{ENV['CCI_REPOS']}/lab-#{@job['lab']}"
    tbox_group = @job['tbox_group'].split(/\.|--/)[0]

    ["#{lab_repo}/hosts/#{@job['testbox']}",
     "#{LKP_SRC}/hosts/#{@job['testbox']}",
     "#{lab_repo}/hosts/#{tbox_group}",
     "#{LKP_SRC}/hosts/#{tbox_group}"].each do |file|
      return file if File.file?(file)
    end

    raise ArgumentError, "hosts file not exist: #{tbox_group}, maybe need check testbox field"
  end

  def include_files
    return @include_files if @include_files

    @include_files = {}
    Dir["#{lkp_src}/include/*"].map do |d|
      key = File.basename d
      @include_files[key] = {}
      Dir["#{lkp_src}/include/#{key}",
          "#{lkp_src}/include/#{key}/*"].each do |f|
            next if File.directory? f

            @include_files[key][File.basename(f)] = f
          end
    end
    @include_files
  end

  def load_one_defaults(file, job)
    return nil unless file
    return nil if @file_loaded.include?(file)
    return nil unless File.exist? file

    context_hash = deepcopy(@defaults)
    revise_hash(context_hash, job, true)
    revise_hash(context_hash, @overrides, true)
    begin
      defaults = load_yaml(file, context_hash)
    rescue KeyError
      return false
    end
    if defaults.is_a?(Hash) && !defaults.empty?
      @defaults.delete_if { |key, _| defaults.has_key?(key) }
      @defaults[source_file_symkey(file)] = nil
      revise_hash(@defaults, defaults, true)
      @defaults.merge!(@overrides)
    end
    @file_loaded[file] = true
    true
  end

  def load_self_config
    self_config_path = "#{ENV['HOME']}/.config/compass-ci"
    Dir.glob(['/etc/compass-ci/defaults/*.yaml',
              "#{self_config_path}/defaults/*.yaml"]).each do |file|
      load_one_defaults(file, @job)
    end

    lab_yaml = File.join(self_config_path, 'include/lab', "#{@defaults['lab']}.yaml")
    load_one_defaults(lab_yaml, @job)

    merge_defaults
    load_hosts_config
  end

  def load_defaults(first_time = true)
    if @job.include? :no_defaults
      merge_defaults first_time
      return
    end

    if first_time
      @file_loaded = {}
    else
      @file_loaded ||= {}
    end

    load_self_config
    i = include_files
    job = deepcopy(@job)
    job['___'] = nil
    @jobx = job
    if @job.include?(:expand_params) && !first_time
      expand_params
      @job = deepcopy(@jobx)
      @job.delete('___')
    else
      expand_each_in(job, @dims_to_expand) do |h, k, v|
        h.delete(k) if v.is_a?(Array)
      end
      expand_params(false)
    end
    @jobx = nil

    for_each_in(job, i.keys) do |_pk, _h, k, v|
      job['___'] = v

      load_one = lambda do |f|
        load_one_defaults(i[k][f], job)
      end

      if @referenced_programs.include?(k) && i.include?(k)
        next unless load_one[k].nil?

        if v.is_a?(Hash)
          v.each do |kk, vv|
            next unless @referenced_programs[k].include? kk

            job['___'] = vv
            load_one[kk]
          end
        end
      end
      next unless v.is_a?(String)

      # For testbox vm-lkp-wsx01-4G,
      # try "vm", "vm-lkp", "vm-lkp-wsx01", "vm-lkp-wsx01-4G" in turn.
      c = v
      prefix = ''
      hit = nil
      loop do
        a, b, c = c.partition(/[:-]/)
        prefix += a
        hit = load_one[prefix]
        break if c.empty?

        prefix += b
      end

      load_one['OTHERS'] if hit.nil?
      load_one['ALL']
    end

    merge_defaults first_time
  end

  def merge_defaults(first_time = true)
    revise_hash(@job, @defaults, false)
    @defaults = {}

    revise_hash(@job, @cmdline_defaults, false)

    return unless first_time

    return if @overrides.empty?

    key = comment_to_symbol('user overrides')
    @job.delete key
    @job[key] = nil
    revise_hash(@job, @overrides, true)
  end

  def save(jobfile)
    @job.delete :no_defaults
    atomic_save_yaml_json @job, jobfile
  end

  def lkp_src
    if @job['user'].is_a?(String) && Dir.exist?("/lkp/#{@job['user']}/src")
      "/lkp/#{@job['user']}/src"
    else
      LKP_SRC
    end
  end

  def available_programs(type)
    @available_programs[type] ||=
      case type
      when Array
        p = {}
        type.each do |t|
          p.merge! available_programs(t)
        end
        p
      when :workload_and_monitors
        # This is all scripts that run in testbox.
        # The other stats/* and filters/* run in server.
        available_programs %i(workload_elements monitors)
      when :workload_elements
        # the options of these programs could impact test result
        available_programs %i(setup tests daemon)
      else
        create_programs_hash "#{type}/**/*", lkp_src
      end
  end

  def read_single_program(key, file)
    options = `#{LKP_SRC}/bin/program-options #{file}`.split("\n")
    @referenced_programs[key] = {}

    options.each do |line|
      type, name = line.split
      @program_options[name] = type
      @referenced_programs[key][name] = nil
    end
  end

  def init_program_options
    @referenced_programs = {}
    @program_options = {
      'cluster' => '-',
      'ucode' => '='
    }
    programs = available_programs(:workload_elements)
    for_each_in(@job, programs) do |_pk, _h, k, _v|
      read_single_program(k, programs[k])
    end
  end

  # program_args: hash for program name and program_name's args
  # program_name: string for program's name
  # option : string for one of program_name's arg
  def get_program_option_value(program_args, program_name, option, option_value=nil)
    unless program_args.is_a?(Hash)
      return option_value
    end
    if program_args.has_key?(option)
      option_value = program_args[option]
    end
    if program_args.has_key?(program_name)
      p_args = program_args[program_name]
      if p_args.is_a?(Hash)
        if p_args.has_key?(option)
          option_value = p_args[option]
        end
      end
      return option_value
    else
      program_args.each do |name, args|
        next if @referenced_programs.include?(name) and not name.eql?(program_name)
        next if name.eql?("pp")
        option_value = get_program_option_value(args, program_name, option, option_value)
      end
    end
    return option_value
  end

  def add_monitors
    @job[comment_to_symbol('auto generated by add_monitors()')] = nil
    @job['monitors'] = nil
    for_each_in(@job, monitor_params) do |_pk, _h, m_n, _m_args|
      @job['monitors'] ||= {}
      @job['monitors'][m_n] = nil
    end
  end

  def get_os_info()
    if @job['testbox'] =~ /^dc/
      docker_image = @job['docker_image'] || 'centos:7'
      return docker_image.split(':')
    end

    default_os = {
      "openeuler" => "20.03",
      "centos" => "7.6.1810",
      "debian" => "sid",
      "ubuntu" => "20.04",
      "fedora" => "33",
      "docker" => "centos:7"
    }
    os = @job['os'] || 'openeuler'
    os_version = @job['os_version'] || default_os[os]
    return os, os_version
  end

  def add_install_depend_packages()
    os, os_version = get_os_info
    all_packages = []

    @job['install_depend_packages'] = {}
    scripts = @job['pp'].keys
    scripts << 'lkp'
    scripts.each do |script|
      packages = get_depend_packages(os, os_version, script)
      next unless packages

      @job['install_depend_packages'][script] = packages.join(' ')
      all_packages += packages
    end
    @job['install_depend_packages_all'] = all_packages.uniq.join(' ')
  end

  def find_cmdline_file(os, os_version, os_arch)
    dir = "#{ENV['LKP_SRC']}/include/manual_install_cmdline/"

    files = []
    files << [ os, os_arch, os_version ].join('-')
    files << [ os, os_arch ].join('-')
    files << os

    files.each do |file|
      return dir+file if File.exists?(dir + file)
    end
  end

  def use_manual_install_cmdline()
    os, os_version = get_os_info
    os_arch = @job['arch'] || @job['os_arch'] || 'aarch64'

    file = find_cmdline_file(os, os_version, os_arch)
    return unless file

    cmdline = load_yaml(file)
    @job.merge!(cmdline)
  end

  def get_depend_packages(os, os_version, script)
    depend_pakeages_path = search_depend_packages_file(os, os_version, script)
    if depend_pakeages_path && File.exist?(depend_pakeages_path)
      return File.read(depend_pakeages_path).split
    end
    get_packages_from_debian(os, script)
  end

  def get_packages_from_debian(os, script)
    depend_pakeages_path = "#{ENV['LKP_SRC']}/distro/depends/#{script}"
    return unless File.exist?(depend_pakeages_path)

    `cat #{depend_pakeages_path} | #{ENV['LKP_SRC']}/sbin/adapt-packages #{os}`.split
  end

  # depend packages priority:
  # - $LKP_SRC/distro/depends/$os/$os_version/$script
  # - $LKP_SRC/distro/depends/$os/$script
  def search_depend_packages_file(os, os_version, script)
    depend_pakeages_dir = "#{ENV['LKP_SRC']}/distro/depends/"
    depend_pakeages_path = File.join(depend_pakeages_dir, os.to_s, os_version.to_s, script)
    return depend_pakeages_path if File.exist?(depend_pakeages_path)

    depend_pakeages_path = File.join(depend_pakeages_dir, os.to_s, script)
    return depend_pakeages_path if File.exist?(depend_pakeages_path)
  end

  def add_pp()
    @job[comment_to_symbol('auto generated by add_pp()')] = nil
    @job["pp"] = Hash.new()
    init_program_options()
    for_each_in(@job, @referenced_programs.keys) do |_pk, h, p_n, _p_args|
      k = hash_key_re_string(h, p_n, @job['pp'].keys)
      if k && h[k] && !h[k].is_a?(Hash)
        @job['pp'][k] = h[k]
        next
      end
      options_hash = @referenced_programs[p_n]
      program_name = hash_key_re_string(h, p_n, @job['pp'].keys)
      next if program_name.nil?

      @job['pp'][program_name] = nil
      options_array = options_hash.keys
      options_array.each do |option|
        option_value = get_program_option_value(@job, program_name, option)
        next if option_value.nil?

        @job['pp'][program_name] ||= {}
        @job['pp'][program_name][option] = option_value
      end
    end
  end

  def add_timeout()
    return if @job['timeout']
    timeout = 0
    timeout = @job["runtime"].to_i if @job["runtime"]
    @job['pp'].each do |program, program_param|
      if program == 'sleep'
        if program_param.is_a?(Hash)
          timeout += program_param['runtime'].to_i if program_param.has_key?('runtime')
        elsif program_param.is_a?(String) || program_param.is_a?(Integer)
          timeout += program_param.to_i
        end
      elsif program_param.is_a?(Hash) && program_param.has_key?('runtime')
        timeout += program_param['runtime'].to_i
      end
    end
    if timeout != 0
      if timeout < 3600
        @job['timeout'] = 3600
      else
        @job['timeout'] = timeout
      end
    end
  end

  # find all create or update files from LKP_SRC directory
  def find_git_change_files()
    git_files_list = Array.new()
    git_status = %x(cd #{LKP_SRC} && git status --porcelain=1 -u)
    git_status_line = git_status.split("\n")
    git_status_line.each do |line|
      git_file = line.split[-1]
      git_file = File.join("#{LKP_SRC}", git_file)
      git_files_list << git_file if File.exist?(git_file)
    end

    git_diff = %x(cd #{LKP_SRC} && git diff --name-only origin/master)
    git_diff_line = git_diff.split("\n")
    git_diff_line.each do |line|
      git_file = line.strip
      git_file = File.join("#{LKP_SRC}", git_file)
      if File.exist?(git_file) && !git_files_list.include?(git_file)
        git_files_list << git_file
      end
    end
    git_files_list
  end

  # add test-user change files to job's define_files
  # the change files is related with test program
  def add_define_files()
    @job["define_files"] = Hash.new()
    git_files_list = find_git_change_files()
    programs_params_hash = @job["pp"] || {}
    program_name_list = programs_params_hash.keys || []
    program_name_list.each do |program|
      program = $1 if program =~ /^(.*)-\d+$/

      # if job is run as makepkg, makepkg-deps, pack-deps, cci-makepkg, cci-depends
      # then use makepkg's benchmark as program to get define_files
      if %w(makepkg makepkg-deps pack-deps cci-makepkg cci-depends).include?(program)
        program = programs_params_hash[program]["benchmark"]
      end

      # this Dir.glob will search for the following paths:
      #       $LKP_SRC/*/$program   $LKP_SRC/*/*/$program
      #       $LKP_SRC/*/$program/* $LKP_SRC/*/*/$program/*
      # $program could be program, program-dev, program.aarch64, program.x86_64.
      Dir.glob("#{LKP_SRC}/{*,*/*}/{#{program},#{program}-dev,#{program}.*}{,/*}").each do |file|
        file = File.realpath(file)
        if git_files_list.include?(file)
          puts "define_file: #{file}"
          relative_path = file.sub("#{LKP_SRC}/", '')
          @job["define_files"][relative_path] = File.read(file)
        end
      end
    end
  end

  def each_job_init
    init_program_options
    @dims_to_expand = Set.new EXPAND_DIMS
    @dims_to_expand.merge @referenced_programs.keys
    @dims_to_expand.merge @program_options.keys
  end

  def expand_each_in(ah, set)
    ah.each do |k, v|
      yield ah, k, v if set.include?(k) || (v.is_a?(String) && v =~ /{{(.*)}}/m)
      next unless v.is_a?(Hash)

      expand_each_in(v, set) do |h, k, v|
        yield h, k, v
      end
    end
  end

  def each_job
    expand_each_in(@job, @dims_to_expand) do |h, k, v|
      if v.is_a?(String) && v =~ /^(.*){{(.*)}}(.*)$/m
        head = $1.lstrip
        tail = $3.chomp.rstrip
        expr = expand_expression(@job, $2, k)
        return if expr.nil?

        h[k] = if head.empty? && tail.empty?
                 expr
               else
                 "#{head}#{expr}#{tail}"
               end
        each_job { |job| yield job }
        h[k] = v
        return
      elsif v.is_a?(Array)
        v.each do |vv|
          h[k] = vv
          each_job { |job| yield job }
        end
        h[k] = v
        return
      end
    end
    job = deepcopy self
    job.load_defaults false
    job.delete :no_defaults
    job.delete :expand_params
    yield job
  end

  def each_jobs(&block)
    each_job_init
    job = deepcopy(@job)
    load_defaults
    each_job_init
    each_job(&block)
    @jobs.each do |hash|
      @job = deepcopy(job)
      @job.merge!(hash)
      load_defaults
      each_job_init
      each_job(&block)
    end
  end

  def each_param
    init_program_options
    read_single_program('wrapper', "#{LKP_SRC}/tests/wrapper")

    # Some programs, especially setup/*, can accept params directly
    # via command line string, ie.
    #
    #   program: param
    #
    # instead of the normal
    #
    #   program:
    #     option1: v1
    #     option2: v2
    #
    # So need to iterate programs, too.
    set = @program_options.merge available_programs(:workload_elements)

    # We also allow program options to be set non-locally, ie.
    #
    #   option1: param1
    #   program:
    #     option2: param2
    #
    monitors = available_programs(:monitors)
    for_each_in(@job, set) do |pk, _h, k, v|
      next if v.is_a?(Hash)

      # skip monitor options which happen to have the same
      # name with referenced :workload_elements programs
      next if pk && monitors.include?(pk)

      yield k, v, @program_options[k]
    end
  end

  def each_program(type)
    for_each_in(@job, available_programs(type)) do |_pk, _h, k, v|
      yield k, v
    end
  end

  def each(&block)
    @job.each(&block)
  end

  def monitor_params
    m = []
    each_program(:monitors) do |k, _v|
      m << k
    end
    m
  end

  def path_params
    sorted_params = []
    each_param { |k, v, option_type| sorted_params << [k, v, option_type] }
    sorted_params = sorted_params.sort_by { |k, _v, _option_type| k }

    path = ''
    sorted_params.each do |k, v, option_type|
      if option_type == '='
        path += if v && v != ''
                  "#{k}=#{v[0..30]}"
                else
                  k.to_s
                end
        path += '-'
        next
      end
      next unless v

      path += v.to_s[0..30]
      path += '-'
    end
    path = path.empty? ? 'defaults' : path.chomp('-').tr('^-a-zA-Z0-9+=:.%', '_')
    path += "-monitor=#{@job['monitor_sha']}" if @job['category'] != 'functional' && @job['monitor_sha']
    path
  end

  def param_files
    @param_files ||= begin
      maps = {}
      ruby_scripts = {}
      misc_scripts = {}
      Dir["#{lkp_src}/params/*",
          "#{lkp_src}/filters/*"].map do |f|
        name = File.basename f
        case name
        when /(.*)\.rb$/
          ruby_scripts[$1] = f
        else
          if File.executable? f
            misc_scripts[name] = f
          else
            maps[name] = f
          end
        end
      end
      [maps, ruby_scripts, misc_scripts]
    end
  end

  def map_param(hash, key, val, rule_file)
    return unless val.is_a?(String)

    ___ = val.dup # for reference by expressions
    output = nil
    rules = read_param_map_rules(rule_file)
    rules.each do |pattern, expression|
      val.sub!(pattern) do |_s|
        # puts s, pattern, expression
        job = JobEval.new @jobx
        o = job.instance_eval(expression)
        case output
        when nil
          output = o
        when Hash
          output.merge! o
        else
          log_error "confused while mapping param: #{___}"
          break 2
        end
        nil
      end
    end
    hash[key] = replace_symbol_keys(output) if output
  end

  def evaluate_param(hash, _key, val, script)
    hash = @jobx.merge(___: val)
    expr = File.read script
    expand_expression(hash, expr, script)
  end

  def job_env(job)
    job_env = {}
    for_each_in(job, available_programs(:workload_elements)) do |_pk, _h, program, env|
      if env.is_a? Hash
        env.each do |key, val|
          key = "#{program}_#{key}".gsub(/[^a-zA-Z0-9_]/, '_')
          job_env[key] = val.to_s
        end
      else
        job_env[program] = env.to_s
      end
    end
    job_env
  end

  def top_env(job)
    top_env = expand_toplevel_vars({}, job)
    top_env['LKP_SRC'] = lkp_src
    top_env['job_file'] = job['job_file'] || @jobfile
    top_env
  end

  def run_filter(_hash, _key, _val, script)
    system @filter_env, script, unsetenv_others: true

    raise Job::ParamError, "#{script}: exitstatus #{$CHILD_STATUS.exitstatus}" if $CHILD_STATUS.exitstatus && $CHILD_STATUS.exitstatus != 0
  end

  def expand_params(run_scripts = true)
    @jobx ||= deepcopy @job
    maps, ruby_scripts, misc_scripts = param_files
    begin
      hash = nil
      file = nil
      for_each_in(@jobx, maps.keys.to_set) do |_pk, h, k, v|
        hash = h
        file = maps[k]
        map_param(h, k, v, file)
      end
      return true unless run_scripts

      for_each_in(@jobx, ruby_scripts.keys.to_set) do |_pk, h, k, v|
        hash = h
        file = ruby_scripts[k]
        evaluate_param(h, k, v, file)
      end
      @filter_env = top_env(@jobx).merge(job_env(@jobx))
      for_each_in(top_env(@jobx), misc_scripts.keys.to_set) do |_pk, h, k, v|
        hash = h
        file = misc_scripts[k]
        run_filter(h, k, v, file)
      end
    rescue TypeError => e
      log_error "#{file}: #{e.message} hash: #{hash}"
      raise
    rescue KeyError => e # no conclusion due to lack of information
      log_error "#{file}: #{e.message} hash: #{hash}"
      return nil
    end
    true
  end

  def axes
    as = {}
    ResultPath::MAXIS_KEYS.each do |k|
      next if k == 'path_params'

      as[k] = @job[k] if @job.key? k
    end

    ## TODO: remove the following lines when we need not
    ## these default processing in the future
    rtp = ResultPath.new
    rtp['testcase'] = @job['testcase']
    path_scheme = rtp.path_scheme
    as['rootfs'] ||= 'debian-x86_64.cgz' if path_scheme.include? 'rootfs'
    as['compiler'] ||= LKP_DEFAULT_COMPILER if path_scheme.include? 'compiler'

    as['rootfs'] = rootfs_filename as['rootfs'] if as.key? 'rootfs'
    each_param do |k, v, option_type|
      if option_type == '='
        as[k] = v.to_s
      elsif v
        as[k] = v.to_s
      end
    end
    as
  end

  def each_commit
    return enum_for(__method__) unless block_given?

    @job.each do |key, val|
      case key
      when 'commit'
        yield val, @job['branch'], 'linux'
      when 'head_commit', 'base_commit'
        nil
      when /_commit$/
        project = key.sub(/_commit$/, '')
        yield val, @job["#{project}_branch"], project
      end
    end
  end

  # TODO: reimplement with axes
  def _result_root
    result_path = ResultPath.new
    result_path.update @job
    @path_scheme = result_path.path_scheme
    result_path['rootfs'] ||= 'debian-x86_64.cgz'
    result_path['rootfs'] = rootfs_filename result_path['rootfs']
    result_path['path_params'] = path_params
    result_path._result_root
  end

  def _boot_result_root(commit)
    result_path = ResultPath.new
    result_path.update @job
    result_path['testcase'] = 'boot'
    result_path['path_params'] = '*'
    result_path['rootfs'] = '*'
    result_path['commit'] = commit
    result_path._result_root
  end

  def [](k)
    @job[k]
  end

  def []=(k, v)
    @job[k] = v
  end

  def include?(k)
    @job.include?(k)
  end

  def has_key?(k)
    @job.include?(k)
  end

  def empty?
    @job.empty?
  end

  def delete(k)
    @job.delete(k)
  end

  def update(k)
    @job.update(k)
  end

  def merge(k)
    @job.merge(k)
  end

  def to_hash
    @job
  end

  def atomic_job?
    @job['arch']
  end
end

class JobEval < Job
  def method_missing(method, *args, &_block)
    job = @job
    method = method.to_s
    if method.chomp!('=')
      job[method] = args.first
    elsif job.include? method
      job[method]
    else
      raise KeyError, "unknown hash key: '#{method}'"
    end
  end
end

class << Job
  def open(jobfile, expand_template = false)
    j = new
    j.load(jobfile, expand_template) && j
  end
end

def each_job_in_dir(dir, job_name = '*.yaml')
  return enum_for(__method__, dir, job_name) unless block_given?

  proc_jobfile = lambda do |jobfile|
    j = Job.open jobfile
    j['jobfile'] = jobfile
    yield j
  end

  Dir.glob(File.join(dir, '**', job_name)).each(&proc_jobfile)
end
