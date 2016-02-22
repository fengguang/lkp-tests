#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']
LKP_SERVER ||= 'inn'

require "#{LKP_SRC}/lib/common.rb"
require "#{LKP_SRC}/lib/result.rb"
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

def for_each_in(ah, set)
	ah.each { |k, v|
		if set.include?(k)
			yield ah, k, v
		end
		if Hash === v
			for_each_in(v, set) { |h, k, v|
				yield h, k, v
			}
		end
	}
end

# programs[script] = full/path/to/script
def __create_programs_hash(glob, lkp_src)
	programs = {}
	Dir.glob("#{lkp_src}/#{glob}").each { |path|
		next if File.directory?(path)
		next if not File.executable?(path)
		file = File.basename(path)
		next if file == 'wrapper'
		if programs.include? file
			$stderr.puts "Conflict names #{programs[file]} and #{path}"
			next
		end
		programs[file] = path
	}
	programs
end

def create_programs_hash(glob, lkp_src = LKP_SRC)
	cache_key = [glob, lkp_src].join ":"
	$programs_cache ||= {}
	if $programs_cache[cache_key]
		$programs = $programs_cache[cache_key]
		return
	end

	$programs = __create_programs_hash(glob, lkp_src)

	$programs_cache[cache_key] = $programs
end

def atomic_save_yaml_json(object, file)
	temp_file = file + "-#{$$}"
	File.open(temp_file, mode='w') { |file|
		if temp_file.index('.json')
			file.write(JSON.pretty_generate(object, :allow_nan => true))
		else
			file.write(YAML.dump(object))
		end
	}
	FileUtils.mv temp_file, file, :force => true
end

def rootfs_filename(rootfs)
	rootfs.split(/[^a-zA-Z0-9._-]/)[-1]
end

class JobFileSyntaxError < RuntimeError
	def initialize(jobfile, syn_msg)
		@jobfile = jobfile
		super "Jobfile: #{jobfile}, syntax error: #{syn_msg}"
	end

	attr_reader :jobfile
end

class Job

	EXPAND_DIMS = %w(kconfig commit rootfs)

	attr_reader :path_scheme

	def update(hash, top = false)
		@job ||= {}
		if top
			@job = hash.merge @job
		else
			@job.update hash
		end
	end

	def load_head(jobfile, top = false)
		return nil unless File.exist? jobfile
		job = YAML.load_file jobfile
		self.update(job, top)
	end

	def load(jobfile)
		yaml = File.read jobfile
		raise ArgumentError.new("empty jobfile #{jobfile}") if yaml.size == 0

		@jobs = []
		YAML.load_stream(yaml) do |hash|
			@jobs << hash
		end

		@job ||= {}
		@job.update @jobs.shift
	end

	def save(jobfile)
		atomic_save_yaml_json @job, jobfile
	end

	def lkp_src
		if @job['user'] and Dir.exist? (dir = '/lkp/' + @job['user'] + '/src')
			dir
		else
			LKP_SRC
		end
	end

	def init_program_options
		@program_options = {
			'cluster' => '-',
		}
		for_each_in(@job, $programs) { |h, k, v|
			`#{LKP_SRC}/bin/program-options #{$programs[k]}`.each_line { |line|
				type, name = line.split
				@program_options[name] = type
			}
		}
	end

	def each_job_init
		create_programs_hash "{setup,tests,daemon}/**/*", lkp_src
		init_program_options
		@dims_to_expand = Set.new EXPAND_DIMS
		@dims_to_expand.merge $programs.keys
		@dims_to_expand.merge @program_options.keys
	end

	def each_job
		for_each_in(@job, @dims_to_expand) { |h, k, v|
			if Array === v
				v.each { |vv|
					h[k] = vv
					each_job { yield self }
				}
				h[k] = v
				return
			end
		}
		yield self
	end

	def each_jobs(&block)
		each_job_init
		each_job &block
		@jobs.each do |hash|
			@job.update hash
			each_job &block
		end
	end

	def each_param
		create_programs_hash "{setup,tests,daemon}/**/*", lkp_src
		init_program_options
		for_each_in(@job, $programs.clone.merge(@program_options)) { |h, k, v|
			next if Hash === v
			yield k, v, @program_options[k]
		}
	end

	def each_program(glob)
		create_programs_hash(glob, lkp_src)
		for_each_in(@job, $programs) { |h, k, v|
			yield k, v
		}
	end

	def each(&block)
		@job.each(&block)
	end

	def path_params
		path = ''
		each_param { |k, v, option_type|
			if option_type == '='
				if v and v != ''
					path += "#{k}=#{v}"
				else
					path += "#{k}"
				end
				path += '-'
				next
			end
			next unless v
			path += v.to_s
			path += '-'
		}
		if path.empty?
			return 'defaults'
		else
			return path.chomp('-').tr('^-a-zA-Z0-9+:.%', '_')
		end
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

	def delete(k)
		@job.delete(k)
	end

	def to_hash
		@job
	end
end

class << Job
	def open(jobfile)
		j = new
		j.load(jobfile) && j
	end
end

module LKP
	class QueuedJob
		attr_reader :id, :_result_root
		def initialize(_result_root, id)
			@_result_root = _result_root
			@id = id
		end

		def completion
			return @completion if @completion

			completions = @_result_root + '/completions'

			if File.exist? completions
				@completion = File.readlines(completions).find {|completion| completion.index @id}
			end
		end

		def stage
			@stage || @stage = self.completion.split(@id).last.split(' ')[1] if self.completed?
		end

		def result_root
			@result_root ||= if self.completed?
				result_root = self.completion.split(@id).last.split(' ')[0]
				# "unite" is "unite failed"
				if ["united", "bad", "unite"].include? self.stage
					result_root
				elsif self.stage == "skipped"
					# 2016-02-19 06:00:48 +0800 ed3c74a721d4c459b336f12f2b19a4ccdd2d5b27 /lkp/scheduled/vm-kbuild-1G-5/validate_boot-1-debian-x86_64-2015-02-07.cgz-x86_64-randconfig-s2-02190153-e5a2e3c8478215aea5b4c58e6154f1b6b170b0ca-20160219-83395-h6q5ri-2.yaml skipped due to already exists
					# 2016-02-19 06:32:47 +0800 7a4db7f7784e3aa284e99e6c9d6c331ef035bdbf /result/boot/1/vm-kbuild-1G/debian-x86_64-2015-02-07.cgz/x86_64-randconfig-s2-02190153/gcc-5/e5a2e3c8478215aea5b4c58e6154f1b6b170b0ca/2 united
					result_root =~ /-(\d+)\.yaml/
					File.join(@_result_root, $1.to_i.to_s)
				end
			end

			@result_root || "#{@_result_root} => #{@id}"
		end

		def status
			if self.completed?
				status = (File.exist?(File.join(self.result_root, "last_state")) ||
				          !["skipped", "united"].include?(self.stage) ||
#				          !File.exist?(File.join(self.result_root, "#{self['testcase']}.success"))
				          File.exist?(File.join(self.result_root, "#{self['testcase']}.fail"))
				         ) ? "FAIL" : "PASS"
				status = "PASS" if File.exist?(File.join(self.result_root, "#{self['testcase']}.success"))
				"#{status} (#{self.stage})"
			else
				"NOT COMPLETED"
			end
		end

		def completed?
			self.completion != nil
		end

		def pass?
			self.status.index "PASS"
		end

		def [](key)
			self.contents[key] if self.contents
		end

		def contents
			@contents ||= if self.completed? && File.exist?(File.join(self.result_root, "job.yaml"))
				YAML.load_file File.join(self.result_root, "job.yaml")
			end
		end

		class << self
			def wait_for(jobs, timeout, options = {})
				if Hash === jobs
					jobs = jobs.map do |_result_root, ids|
						ids.map {|id| self.new _result_root, id}
					end.flatten.uniq(&:id)
				end

				Timeout::timeout(timeout) {
					if options[:verbose]
						start = Time.now
						print "[#{start.strftime('%Y-%m-%d %H:%M:%S')}] wait for #{jobs.size} jobs "
					end

					while true
						print "x" if options[:verbose]

						if jobs.all?(&:completed?)
							if options[:wait_shadow]
								job_ids = jobs.map(&:id)
								shadows = jobs.reject {|job| job_ids.include? job['id']}
								unless shadows.empty?
									jobs.concat(shadows.map {|shadow| self.new shadow._result_root, shadow['id']}.uniq(&:id))
									print " => #{jobs.size} jobs " if options[:verbose]
									next
								end
							end

							break
						end

						sleep 60
					end

					puts " [#{(Time.now - start) / 60}m]" if options[:verbose]
				}

				jobs
			end
		end
	end
end

