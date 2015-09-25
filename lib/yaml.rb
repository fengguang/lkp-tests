#!/usr/bin/env ruby

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
				$stderr.puts "Move corrupted YAML file to .#{file}-bad"
				$stderr.puts "#{file}: " + e.message
				$stderr.puts e.backtrace.join("\n")
				FileUtils.mv file, '.' + file + '-bad'
			end
		else
			$stderr.puts "YAML file does not exist: #{file}"
			$stderr.puts "#{file}: " + e.message
			$stderr.puts e.backtrace.join("\n")
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
			$stderr.puts "YAML is not a hash: #{file} #{yaml[0..300]}"
		end
	end
	return all
end

def load_yaml_tail(file)
	begin
		return YAML.load %x[ tail -n 100 #{file} ]
	rescue Psych::SyntaxError => e
		$stderr.puts "#{file}: " + e.message
	end
	return nil
end

#
# this is specifically used for wtmp file load to handle error caused by machine crash
# though it also be extended to handle wtmp file concept
#
class WTMP
	class << self
		def load(content)
			# FIXME rli9 YAML.load returns false under certain error like empty content
			YAML.load content
		rescue Psych::SyntaxError => e
			# FIXME rli9 only do below gsub when error is control characters error
			# error can be below which is caused by server crash, and try to remove non-printable characters to resolve
			# 	Psych::SyntaxError: (<unknown>): control characters are not allowed at line 1 column 1

			# remvoe all cntrl but keep \n
			YAML.load(content.gsub(/[[[:cntrl:]]&&[^\n]]/, ''))
		end

		def load_tail(file)
			# FIXME rli9 file existence check
			tail = %x[ tail -n 100 #{file} ]

			load(tail)
		rescue Exception => e
			$stderr.puts "#{file}: " + e.message
		end
	end
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

def load_json(file, cache = false)
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
				return obj unless cache
				$json_cache[file] = obj
				$json_mtime[file] = mtime
			end
			return $json_cache[file].freeze
		rescue SignalException
			raise
		rescue Exception
			tempfile = file + "-bad"
			$stderr.puts "Failed to load JSON file: #{file}"
			$stderr.puts "Kept corrupted JSON file for debugging: #{tempfile}"
		        FileUtils.mv file, tempfile, :force => true
			raise
		end
		return nil
	elsif File.exist? file.sub(/\.json(\.gz)?$/, ".yaml")
		return load_yaml file.sub(/\.json(\.gz)?$/, ".yaml")
	else
		$stderr.puts "JSON/YAML file not exist: #{file}"
		$stderr.puts caller
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

class JSONFileNotExistError < StandardError
	def initialize(path)
		super "Failed to load JSON for #{path}"
		@path = path
	end

	attr_reader :path
end

def search_load_json(path)
	try_load_json(path) or
	try_load_json(path + '/matrix.json') or
	try_load_json(path + '/stats.json') or raise(JSONFileNotExistError, path)
end

def load_regular_expressions(file)
	pattern	= File.read(file).split("\n")
	regex	= Regexp.new pattern.join('|')
end
