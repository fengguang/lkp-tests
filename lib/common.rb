LKP_SRC ||= ENV['LKP_SRC']

## common utilities

require "pathname"
require 'fileutils'

def deepcopy(o)
	Marshal.load(Marshal.dump(o))
end

# Take a look at class Commit for usage
module AddCachedMethod
	def add_cached_method(method_name, prefix = 'cached_')
		define_method("#{prefix}#{method_name}") { |key, *args|
			@__cache_for_add_cached_method__ ||= {}
			cache = @__cache_for_add_cached_method__
			mkey = [method_name, key]
			cache[mkey] or cache[mkey] = send(method_name, *args)
		}
	end
end

def instance_variable_sym(str)
	"@#{str}".intern
end

def with_set_globals(*var_val_list)
	var_vals = var_val_list.each_slice(2).to_a
	ovals = var_vals.map { |var, val| eval(var.to_s) }
	var_vals.each { |var, val| eval "#{var} = val" }
	yield
ensure
	if ovals
		var_vals.zip(ovals).map { |var_val, oval|
			var, val = var_val
			eval("#{var} = oval")
		}
	end
end

def ensure_array(obj)
	if obj.is_a? Array
		obj
	else
		[obj]
	end
end

class Array
	# multiple two arrays via multiple element with same index,
	# return the result array.
	def pos_mulitple(an_arr)
		zip(an_arr).map { |v1, v2| v1 * v2 }
	end
end

def string_to_num(str)
	str.index('.') ? str.to_f : str.to_i
end

def remove_common_head(arr1, arr2)
	s = [arr1.size, arr2.size].min
	(0...s).each { |i|
		if arr1[i] != arr2[i]
			return [arr1[i...arr1.size], arr2[i...arr2.size]]
		end
	}
	[arr1[s...arr1.size] || [], arr2[s...arr2.size] || []]
end

## Pathname

def ensure_dir(dir)
	dir[-1] == '/' ? dir : dir + '/'
end

def split_path(path)
	path.split('/').select { |c| c && c.size != 0 }
end

def canonicalize_path(path, dir = nil)
	abs_path = File.absolute_path(path, dir)
	Pathname.new(abs_path).cleanpath.to_s
end

module DirObject
	def to_s
		@path
	end

	def path(*sub)
		File.join @path, *sub
	end

	def open(sub, *args, &b)
		sub = ensure_array(sub)
		File.open path(*sub), *args, &b
	end

	def glob(pattern, flags = nil, &b)
		fpattern = path pattern
		if flags
			Dir.glob fpattern, flags, &b
		else
			Dir.glob fpattern, &b
		end
	end

	def chdir(&b)
		Dir.chdir @path, &b
	end

	def run_in(cmd)
		chdir {
			system cmd
		}
	end

	def bash
		run_in('/bin/bash -i')
	end
end

## IO redirection

def pager
	saved_stdout = $stdout
	IO.popen("/usr/bin/less","w") { |io|
		$stdout = io
		yield
	}
ensure
	$stdout = saved_stdout
end

def redirect(*args)
	if args.empty?
		args = ['stdout.txt', 'w']
	end
	saved_stdout = $stdout
	File.open(*args) { |f|
		$stdout = f
		yield
	}
ensure
	$stdout = saved_stdout
end

## Date and time

ONE_DAY = 60 * 60 * 24
DATE_GLOB = '????-??-??'.freeze

def str_date(t)
	t.strftime('%F')
end

## File system

def make_relative_symlink(src, dst)
	if File.directory? dst
		dst = File.join(dst, File.basename(src))
	end
	return if File.exists? dst
	src_comps = split_path(src)
	dst_comps = split_path(dst)
	src_comps, dst_comps = remove_common_head(src_comps, dst_comps)
	rsrc = File.join([".."] * (dst_comps.size - 1) + src_comps)
	File.symlink(rsrc, dst)
end

def mkdir_p(dir, mode = 02755)
	FileUtils.mkdir_p dir, :mode => mode
end

def with_flock(lock_file)
	File.open(lock_file, File::RDWR|File::CREAT, 0644) { |f|
		f.flock(File::LOCK_EX)
		yield
	}
end
