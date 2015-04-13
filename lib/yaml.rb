#!/usr/bin/ruby

LKP_SRC ||= ENV['LKP_SRC']

require "#{LKP_SRC}/lib/common.rb"
require 'fileutils'
require 'yaml'
require 'json'

def compress_file(file)
	system "gzip #{file} < /dev/null"
end

def load_yaml(file)
	begin
		obj = YAML.load_file file
		return obj
	rescue SignalException
		raise
	rescue Exception => e
		if File.exist? file
			if File.size(file) == 0
				puts "YAML file is empty: #{file}"
			else
				STDERR.puts "Move corrupted YAML file to .#{file}-bad"
				STDERR.puts "#{file}: " + e.message
				STDERR.puts e.backtrace.join("\n")
				FileUtils.mv file, '.' + file + '-bad'
			end
		else
			STDERR.puts "YAML file does not exist: #{file}"
			STDERR.puts "#{file}: " + e.message
			STDERR.puts e.backtrace.join("\n")
		end
		raise
	end
	return nil
end

def load_yaml_merge(files)
	all = {}
	files.each do |file|
		next unless File.exist? file
		yaml = load_yaml(file)
		if Hash === yaml
			all.update(yaml)
		elsif yaml
			STDERR.puts "YAML is not a hash: #{file} #{yaml[0..300]}"
		end
	end
	return all
end

def load_yaml_tail(file)
	begin
		return YAML.load %x[ tail -n 100 #{file} ]
	rescue Psych::SyntaxError => e
		STDERR.puts "#{file}: " + e.message
	end
	return nil
end

def dot_file(path)
	File.dirname(path) + '/.' + File.basename(path)
end

def save_yaml(object, file, compress=false)
	temp_file = dot_file(file) + "-#{$$}"
	File.open(temp_file, mode='w') { |f|
		f.write(YAML.dump(object))
	}
	FileUtils.mv temp_file, file, :force => true

	compress_file(file) if compress
end

$json_cache = {}
$json_mtime = {}

def load_json(file)
	if (file =~ /.json(\.gz)?$/ and File.exist? file) or
	   (file =~ /.json$/ and File.exist? file + '.gz' and file += '.gz')
		begin
			mtime = File.mtime(file)
			unless $json_cache[file] and $json_mtime[file] == mtime
				if file =~ /\.json$/
					obj = JSON.load File.read(file)
				else
					obj = JSON.load `zcat #{file}`
				end
				$json_cache[file] = obj
				$json_mtime[file] = mtime
			end
			return deepcopy($json_cache[file])
		rescue SignalException
			raise
		rescue Exception
			tempfile = file + "-bad"
			STDERR.puts "Failed to load JSON file: #{file}"
			STDERR.puts "Kept corrupted JSON file for debugging: #{tempfile}"
		        FileUtils.mv file, tempfile, :force => true
			raise
		end
		return nil
	elsif File.exist? file.sub(/\.json(\.gz)?$/, ".yaml")
		return load_yaml file.sub(/\.json(\.gz)?$/, ".yaml")
	else
		STDERR.puts "JSON/YAML file not exist: #{file}"
		STDERR.puts caller
		return nil
	end
end

def save_json(object, file, compress=false)
	temp_file = dot_file(file) + "-#{$$}"
	File.open(temp_file, mode='w') { |file|
		file.write(JSON.pretty_generate(object, :allow_nan => true))
	}
	FileUtils.mv temp_file, file, :force => true

	compress_file(file) if compress
end

def try_load_json(path)
	if File.file? path
		load_json(path)
	elsif path =~ /.json$/
		if File.file? path + '.gz'
			load_json(path + '.gz')
		elsif File.file? path.sub(/\.json$/, ".yaml")
			load_json(path)
		end
	end
end

def search_load_json(path)
	try_load_json(path) or
	try_load_json(path + '/matrix.json') or
	try_load_json(path + '/stats.json') or raise "Failed to load JSON for #{path}"
end

def load_regular_expressions(file)
	pattern	= File.read(file).split
	regex	= Regexp.new pattern.join('|')
end
