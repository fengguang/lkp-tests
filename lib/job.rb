#!/usr/bin/ruby

LKP_SRC ||= ENV['LKP_SRC']
LKP_SERVER ||= 'inn'

require 'fileutils'
require 'yaml'
require 'pp'

def deepcopy(o)
	Marshal.load(Marshal.dump(o))
end

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
		s = files.keys.sort.join ' '
	end
	return s
end

def expand_toplevel_vars(env, hash)
	vars = {}
	hash.each { |key, val|
		case val
		when Hash
			next
		when Array
			vars[key] = expand_shell_var(env, val[0] || 1) if val.size == 1
		else
			vars[key] = expand_shell_var(env, val || 1)
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

def strip_trivial_array(a)
	if a.class == Array
		return a[0]
	else
		return a
	end
end

def for_each(ah)
	if ah.class == Array
		ah.each { |a|
			for_each(a) { |k, v|
				yield k, v
			}
		}
	elsif ah.class == Hash
		ah.each { |k, v|
			yield k, v
		}
	elsif ah and ah != ''
		yield ah, nil
	end
end

def for_each_program(ah)
	for_each(ah) { |k, v|
		# puts k
		if $programs.include? k
			yield k, v
		elsif Hash === v
			for_each_program(v) { |k, v|
				yield k, v
			}
		end
	}
end

def for_each_program_or_param(ah)
	for_each(ah) { |k, v|
		# puts k
		if $programs.include? k
			if (v.class == Array and v.size > 1) or (v.class == Hash and v.size >= 1)
				if $programs[k] == ''
					options = []
				else
					options = `#{LKP_SRC}/bin/program-options #{$programs[k]}`.split
				end
				if options.include? string_or_hash_key(strip_trivial_array(v)) 
					if v.class == Hash
						v.each { |kk, vv| yield kk, vv }
					# elsif v.class == Array
						# v.each { |kk| yield kk, vv }
					end
				else
					yield k, v
				end
			else
				yield k, v
			end
		elsif Hash === v
			for_each_program_or_param(v) { |k, v|
				yield k, v
			}
		end
	}
end

# programs[script] = full/path/to/script
def create_programs_hash(glob)
	$programs = {}
	Dir.glob("#{LKP_SRC}/#{glob}").each { |path|
		next if File.directory?(path)
		next if not File.executable?(path)
		file = File.basename(path)
		next if file == 'wrapper'
		if $programs.include? file
			STDERR.puts "Conflict names #{$programs[file]} and #{path}"
			next
		end
		$programs[file] = path
	}
end

def atomic_save_yaml(object, file)
	temp_file = file + "-#{$$}"
	File.open(temp_file, mode='w') { |file|
		file.write(YAML.dump(object))
	}
	FileUtils.mv temp_file, file, :force => true
end

def tbox_group(hostname)
	hostname.sub /-[0-9]+$/, ''
end

class Job

	def load(jobfile)
		begin
			yaml = File.read jobfile
			@jobs = []
			YAML.load_stream(yaml, jobfile) do |hash|
				@jobs << hash
			end
			@job = YAML.load_file "#{LKP_SRC}/jobs/DEFAULTS"
			@job.update @jobs.shift
		rescue Errno::ENOENT
			return nil
		rescue Exception
			STDERR.puts "Failed to open job #{jobfile}: #{$!}"
			if File.size(jobfile) == 0
				STDERR.puts "Removing empty job file #{jobfile}"
				FileUtils.rm jobfile
			end
			raise
		end
	end

	def save(jobfile)
		atomic_save_yaml @job, jobfile
	end

	def each_job
		create_programs_hash "{setup,tests}/**/*"
		$programs['commit'] = '' # help split the cyclic job's commit: [BASE, HEAD]
		last_item = ''
		for_each_program_or_param(@job) { |k, v| last_item = k }
		for_each_program_or_param(@job) { |k, v|
			if (v.class == Array or v.class == Hash) and v.size > 1
				copy = deepcopy(v)
				for_each(copy) { |kk, vv|
					restore(v, copy)
					v.keep_if { |a, b| a == kk }
					# expand_one(job) { |job| yield job }
					each_job { yield self }
				}
				restore(v, copy)
				break
			elsif k == last_item
				yield self
			end
		}
	end

	def each_jobs(&block)
		each_job &block
		@jobs.each do |hash|
			@job.update hash
			each_job &block
		end
	end

	def each_param
		create_programs_hash "{setup,tests}/**/*"
		for_each_program(@job) { |k, v|
			if $programs[k] == ''
				options = []
			else
				options = `#{LKP_SRC}/bin/program-options #{$programs[k]}`.split
			end
			if v.class == Hash
				v.each { |kk, vv| yield kk, options.include?(kk) ? strip_trivial_array(vv) : kk }
			elsif v.class == Array
				if v[0].class == Hash
					v[0].each { |kk, vv| yield kk, options.include?(kk) ? strip_trivial_array(vv) : kk }
				else
					yield k, v[0]
				end
			else
				yield k, v
			end
		}
	end

	def each_program(glob)
		create_programs_hash(glob)
		for_each_program(@job) { |k, v|
			yield k, v
		}
	end

	def path_params
		path = ''
		each_param { |k, v|
			next unless v
			path += v.to_s.tr('/$()', '_')
			path += '-'
		}
		if path.empty?
			return 'defaults'
		else
			return path.chomp('-')
		end
	end

	def _result_root
		commit = @job['commit']
		"/result/#{tbox_group(@job['testbox'])}/#{@job['testcase']}/#{self.path_params}/#{@job['kconfig']}/#{commit}"
	end

	def [](k)
		strip_trivial_array(@job[k])
	end

	def []=(k, v)
		@job[k] = v
	end

	def delete(k)
		@job.delete(k)
	end
end
