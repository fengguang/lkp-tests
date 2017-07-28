#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath(__FILE__)))
LKP_SERVER ||= 'inn'

require "#{LKP_SRC}/lib/common.rb"
require "#{LKP_SRC}/lib/result.rb"
require "#{LKP_SRC}/lib/hash.rb"
require "#{LKP_SRC}/lib/erb.rb"
require "#{LKP_SRC}/lib/log"
require 'fileutils'
require 'yaml'
require 'json'
require 'set'
require 'pp'

def restore(ah, copy)
  if ah.class == Hash
    ah.clear.merge!(copy)
  elsif ah.class == Array
    ah.clear.concat(copy)
  end
end

def expand_shell_var(env, o)
  s = o.to_s
  return s if `hostname`.chomp == LKP_SERVER
  if s.index('$')
    f = IO.popen(env, ['/bin/bash', '-c', 'eval echo "' + s + '"'], 'r')
    s = f.read.chomp
    f.close
  elsif s.index('/dev/disk/')
    files = {}
    s.split.each { |f|
      Dir.glob(f).each { |d| files[File.realpath d] = d }
    }
    s = files.keys.sort_by { |dev|
      dev =~ /(\d+)$/
      $1.to_i
    }.join ' '
  end
  return s
end

def expand_toplevel_vars(env, hash)
  vars = {}
  hash.each { |key, val|
    next unless String === key
    case val
    when Hash
      next
    when nil
      vars[key] = nil
    when Array
      vars[key] = expand_shell_var(env, val[0]) if val.size == 1
    else
      vars[key] = expand_shell_var(env, val)
    end
  }
  return vars
end

def string_or_hash_key(h)
  if h.class == Hash
    # assert h.size == 1
    return h.keys[0]
  else
    return h
  end
end

def for_each_in(ah, set, pk = nil)
  ah.each { |k, v|
    if set.include?(k)
      yield pk, ah, k, v
    end
    if Hash === v
      for_each_in(v, set, k) { |pk, h, k, v|
        yield pk, h, k, v
      }
    end
  }
end

# programs[script] = full/path/to/script
def __create_programs_hash(glob, lkp_src)
  programs = {}
  Dir.glob("#{lkp_src}/#{glob}").each { |path|
    next if File.directory?(path)
    next if path =~ /\.yaml$/
    next if path =~ /\.[0-9]+$/
    if not File.executable?(path)
      log_warn "skip non-executable #{path}"
      next
    end
    file = File.basename(path)
    next if file == 'wrapper'
    if programs.include? file
      log_error "Conflict names #{programs[file]} and #{path}"
      next
    end
    programs[file] = path
  }
  programs
end

def create_programs_hash(glob, lkp_src = LKP_SRC)
  cache_key = [glob, lkp_src].join ":"
  $programs_cache ||= {}
  $programs =
  $programs_cache[cache_key] ||= __create_programs_hash(glob, lkp_src).freeze
end

def atomic_save_yaml_json(object, file)
  temp_file = file + "-#{$$}"
  File.open(temp_file, mode='w') { |file|
    if temp_file.index('.json')
      lines = JSON.pretty_generate(object, :allow_nan => true)
    else
      lines = YAML.dump(object)
      # create comment lines from symbols
      lines.gsub!(/^:#(.*): $/, "\n#\\1")
      lines.gsub!(/^\? :#(.*)\n: $/, "\n#\\1")
    end
    file.write(lines)
  }
  FileUtils.mv temp_file, file, :force => true
end

def rootfs_filename(rootfs)
  rootfs.split(/[^a-zA-Z0-9._-]/)[-1]
end

def comment_to_symbol(str)
  :"#! #{str}"
end

def replace_symbol_keys(hash)
  return hash unless Hash === hash
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
    head, rule, lines = lines.partition /^\/(.*?[^\\])\/\s+/
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
end

class Job

  EXPAND_DIMS = %w(kconfig commit rootfs)

  attr_reader :path_scheme
  attr_accessor :overrides
  attr_accessor :defaults

  def initialize(job = {}, defaults = {}, overrides = {})
    @job = job
    @defaults = defaults  # from auto includes
    @overrides = overrides  # from command line
    @available_programs = {}
  end

  def source_file_symkey(file)
    comment_to_symbol file.sub(lkp_src + '/', '')
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
    raise ArgumentError.new("empty jobfile #{jobfile}") if yaml.size == 0

    # keep comment lines as symbols
    yaml.gsub!(/\n\n#([! ][-a-zA-Z0-9 !|\/?@<>.,_+=%~]+)$/, "\n:#\\1: ")

    begin
      if expand_template
        yaml = expand_yaml_template(yaml, jobfile)
      end

      @jobs = []
      YAML.load_stream(yaml) do |hash|
        @jobs << hash
      end
    rescue StandardError => e
      log_error "#{jobfile}: " + e.message
      log_error '-' * 80
      log_error yaml
      log_error '-' * 80
      raise
    end

    @job = Hash.new
    unless @jobs.first['job_origin']
      if File.symlink?(jobfile) and
         File.readlink(jobfile) =~ %r|^../../../(.*)|
        @job[comment_to_symbol $1] = nil
      else
        @job[source_file_symkey jobfile] = nil
      end
    end
    @job.merge!(@jobs.shift)
    @job['job_origin'] ||= jobfile
    @jobfile = jobfile
  end

  def load_hosts_config
    return if @job.include? :no_defaults
    return unless @job.include? 'tbox_group'
    hosts_file = "#{lkp_src}/hosts/#{@job['tbox_group']}"
    return unless File.exist? hosts_file
    hwconfig = load_yaml(hosts_file, nil)
    @job[source_file_symkey(hosts_file)] = nil
    @job.merge!(hwconfig) { |k, a, b| a } # job's key/value has priority over hwconfig
  end

  def include_files
    return @include_files if @include_files
    @include_files = {}
    Dir["#{lkp_src}/include/*"].map do |d|
      key = File.basename d
      @include_files[key] = {}
      Dir["#{lkp_src}/include/#{key}",
          "#{lkp_src}/include/#{key}/*"].each { |f|
        next if File.directory? f
        @include_files[key][File.basename(f)] = f
      }
    end
    @include_files
  end

  def load_one_defaults(file, job)
    return nil unless File.exist? file
    context_hash = deepcopy(@defaults)
    revise_hash(context_hash, job, true)
    revise_hash(context_hash, @overrides, true)
    begin
      defaults = load_yaml(file, context_hash)
    rescue KeyError
      return false
    end
    if Hash === defaults and not defaults.empty?
      @defaults[source_file_symkey(file)] = nil
      revise_hash(@defaults, defaults, true)
    end
    return true
  end

  def load_defaults(first_time = true)
    if @job.include? :no_defaults
      merge_defaults first_time
      return
    end

    if first_time
      @file_loaded = Hash.new
    else
      @file_loaded ||= Hash.new
    end

    i = include_files
    job = deepcopy(@job)
    revise_hash(job, deepcopy(@job2), true)
    revise_hash(job, deepcopy(@overrides), true)
    job['___'] = nil
    expand_each_in(job, @dims_to_expand) { |h, k, v|
      h.delete(k) if Array === v
    }
    @jobx = job
    expand_params(false)
    @jobx = nil
    for_each_in(job, i.keys) do |pk, h, k, v|
      job['___'] = v

      load_one = lambda do |f|
        break unless i[k][f]
        break if @file_loaded.include?(k) and
           @file_loaded[k].include?(f)

        break unless load_one_defaults(i[k][f], job)

        @file_loaded[k]  ||= {}
        @file_loaded[k][f] = true
      end

      if @referenced_programs.include?(k) and i.include? k
        next if load_one[k] != nil
        if Hash === v
          v.each { |kk, vv|
            next unless @referenced_programs[k].include? kk
            job['___'] = vv
            load_one[kk]
          }
        end
      end
      next unless String === v

      # For testbox vm-lkp-wsx01-4G,
      # try "vm", "vm-lkp", "vm-lkp-wsx01", "vm-lkp-wsx01-4G" in turn.
      c = v
      prefix = ''
      hit = nil
      loop do
        a, b, c = c.partition /[:-]/
        prefix += a
        hit = load_one[prefix]
        break if c.empty?
        prefix += b
      end

      load_one['OTHERS'] if hit == nil
      load_one['ALL']
    end

    merge_defaults first_time
  end

  def merge_defaults(first_time = true)
    revise_hash(@job, @defaults, false)
    @defaults = {}

    return unless first_time
    revise_hash(@job, @job2, true)

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
    if String === @job['user'] and Dir.exist? (dir = '/lkp/' + @job['user'] + '/src')
      dir
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

  def referenced_programs
    @referenced_programs
  end

  def init_program_options
    @referenced_programs = {}
    @program_options = {
      'cluster' => '-',
      'ucode' => '=',
    }
    programs = available_programs(:workload_elements)
    for_each_in(@job, programs) { |pk, h, k, v|
      options = `#{LKP_SRC}/bin/program-options #{programs[k]}`.split("\n")
      @referenced_programs[k] = {}
      options.each { |line|
        type, name = line.split
        @program_options[name] = type
        @referenced_programs[k][name] = nil
      }
    }
  end

  def each_job_init
    init_program_options
    @dims_to_expand = Set.new EXPAND_DIMS
    @dims_to_expand.merge @referenced_programs.keys
    @dims_to_expand.merge @program_options.keys
  end

  def expand_each_in(ah, set)
    ah.each { |k, v|
      if set.include?(k) or (String === v and v =~ /{{(.*)}}/m)
        yield ah, k, v
      end
      if Hash === v
        expand_each_in(v, set) { |h, k, v|
          yield h, k, v
        }
      end
    }
  end

  def each_job
    expand_each_in(@job, @dims_to_expand) { |h, k, v|
      if String === v and v =~ /^(.*){{(.*)}}(.*)$/m
        head = $1.lstrip
        tail = $3.chomp.rstrip
        expr = expand_expression(@job, $2, k)
        return if expr == nil
        if head.empty? and tail.empty?
          h[k] = expr
        else
          h[k] = "#{head}#{expr}#{tail}"
        end
        each_job { |job| yield job }
        h[k] = v
        return
      elsif Array === v
        v.each { |vv|
          h[k] = vv
          each_job { |job| yield job }
        }
        h[k] = v
        return
      end
    }
    job = deepcopy self
    job.load_defaults false
    job.delete :no_defaults
    job.set_default_params
    yield job
  end

  def each_jobs(&block)
    each_job_init
    load_hosts_config
    job = deepcopy(@job)
    @job2 = {}
    load_defaults
    each_job_init
    each_job &block
    @jobs.each do |hash|
      @job = deepcopy(job)
      @job2 = hash
      load_defaults
      each_job_init
      each_job &block
    end
  end

  def each_param
    init_program_options

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
    for_each_in(@job, set) { |pk, h, k, v|
      next if Hash === v

      # skip monitor options which happen to have the same
      # name with referenced :workload_elements programs
      next if pk and monitors.include? pk

      yield k, v, @program_options[k]
    }
  end

  def each_program(type)
    for_each_in(@job, available_programs(type)) { |pk, h, k, v|
      yield k, v
    }
  end

  def each(&block)
    @job.each(&block)
  end

  def set_default_params
    return if @job['kconfig'] and
        @job['compiler']

    @job[comment_to_symbol 'default params'] = nil

    @job['kconfig']  ||= DEVEL_HOURLY_KCONFIGS[0]
    @job['compiler'] ||= DEFAULT_COMPILER
  end

  def path_params
    path = ''
    each_param { |k, v, option_type|
      if option_type == '='
        if v and v != ''
          path += "#{k}=#{v[0..30]}"
        else
          path += "#{k}"
        end
        path += '-'
        next
      end
      next unless v
      path += v.to_s[0..30]
      path += '-'
    }
    if path.empty?
      return 'defaults'
    else
      return path.chomp('-').tr('^-a-zA-Z0-9+=:.%', '_')
    end
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
    return unless String === val
    ___ = val.dup # for reference by expressions
    output = nil
    rules = read_param_map_rules(rule_file)
    rules.each do |pattern, expression|
      val.sub!(pattern) do |s|
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

  def evaluate_param(hash, key, val, script)
    hash = @jobx.merge({___: val})
    expr = File.read script
    expand_expression(hash, expr, script)
  end

  def job_env(job)
    job_env = {}
    for_each_in(job, available_programs(:workload_elements)) do |pk, h, program, env|
      if env.is_a? Hash
        env.each { |key, val|
          key = "#{program}_#{key}".gsub(/[^a-zA-Z0-9_]/, '_')
          job_env[key] = val.to_s
        }
      else
        job_env[program] = env.to_s
      end
    end
    job_env
  end

  def top_env(job)
    top_env = expand_toplevel_vars Hash.new, job
    top_env['LKP_SRC'] = lkp_src
    top_env['job_file'] = job['job_file'] || @jobfile
    top_env
  end

  def run_filter(hash, key, val, script)

    system @filter_env, script, {unsetenv_others: true}

    if $?.exitstatus and $?.exitstatus != 0
      raise Job::ParamError, "#{script}: exitstatus #{$?.exitstatus}"
    end
  end

  def expand_params(run_scripts = true)
    @jobx ||= deepcopy @job
    maps, ruby_scripts, misc_scripts = param_files
    begin
      hash = nil
      file = nil
      for_each_in(@jobx, maps.keys.to_set) { |pk, h, k, v|
        hash = h
        file = maps[k]
        map_param(h, k, v, file)
      }
      return true unless run_scripts
      for_each_in(@jobx, ruby_scripts.keys.to_set) { |pk, h, k, v|
        hash = h
        file = ruby_scripts[k]
        evaluate_param(h, k, v, file)
      }
      @filter_env = top_env(@jobx).merge(job_env(@jobx))
      for_each_in(@jobx, misc_scripts.keys.to_set) { |pk, h, k, v|
        hash = h
        file = misc_scripts[k]
        run_filter(h, k, v, file)
      }
    rescue TypeError => e
      log_error "#{file}: #{e.message} hash: #{hash}"
      raise
    rescue KeyError # no conclusion due to lack of information
      return nil
    end
    true
  end
  def axes
    as = {}
    ResultPath::MAXIS_KEYS.each { |k|
      next if k == 'path_params'
      as[k] = @job[k] if @job.has_key? k
    }

    ## TODO: remove the following lines when we need not
    ## these default processing in the future
    rtp = ResultPath.new
    rtp['testcase'] = @job['testcase']
    path_scheme = rtp.path_scheme
    if path_scheme.include? 'rootfs'
      as['rootfs'] ||= 'debian-x86_64.cgz'
    end
    if path_scheme.include? 'compiler'
      as['compiler'] ||= DEFAULT_COMPILER
    end

    if as.has_key? 'rootfs'
      as['rootfs'] = rootfs_filename as['rootfs']
    end
    each_param { |k, v, option_type|
      if option_type == '='
        as[k] = "#{v}"
      else
        as[k] = "#{v}" if v
      end
    }
    as
  end

  def each_commit
    block_given? or return enum_for(__method__)

    @job.each { |key, val|
      case key
      when 'commit'
        yield val, @job['branch'], 'linux'
      when 'head_commit', 'base_commit'
        nil
      when /_commit$/
        project = key.sub /_commit$/, ''
        yield val, @job["#{project}_branch"], project
      end
    }
  end

  # TODO: reimplement with axes
  def _result_root
    result_path = ResultPath.new
    result_path.update @job
    @path_scheme = result_path.path_scheme
    result_path['rootfs'] ||= 'debian-x86_64.cgz'
    result_path['rootfs'] = rootfs_filename result_path['rootfs']
    result_path['path_params'] = self.path_params
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
end

class JobEval < Job
  def method_missing(method, *args, &block)
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

def each_job_in_dir(dir)
  return enum_for(__method__, dir) unless block_given?

  proc_jobfile = ->jobfile{
    j = Job.open jobfile
    j['jobfile'] = jobfile
    yield j
  }

  Dir.glob(File.join(dir, "**/*.yaml")).each(&proc_jobfile)
end

