LKP_SRC ||= ENV['LKP_SRC']

## common utilities

require "timeout"
require "pathname"
require "fileutils"
require "stringio"
require "#{LKP_SRC}/lib/array_ext"

LKP_DATA_DIR = '/data'

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

def array_add!(arr_dst, arr_src)
	0.upto(arr_dst.size - 1) { |i|
		arr_dst[i] += arr_src[i]
	}
end

# Array "-" + "uniq!" with block to calculate key
def array_subtract(arr1, arr2, &blk_key)
	if blk_key
		harr = {}
		arr1.each { |e|
			harr[blk_key.(e)] = e
		}
		arr2.each { |e|
			harr.delete blk_key.(e)
		}
		harr.values
	else
		arr1 - arr2
	end
end

def string_to_num(str)
	str.index('.') ? str.to_f : str.to_i
end

def array_diff_index(arr1, arr2)
	s = [arr1.size, arr2.size].min
	(0...s).each { |i|
		if arr1[i] != arr2[i]
			return i
		end
	}
	s
end

def array_common_head(arr1, arr2)
	s = array_diff_index arr1, arr2
	arr1[0...s] || []
end

def remove_common_head(arr1, arr2)
	s = array_diff_index arr1, arr2
	[arr1[s...arr1.size] || [], arr2[s...arr2.size] || []]
end

## IO

def format_number(number)
	case number
	when Float
		an = number.abs
		fmt =
      if an < 0.001
        '%.4g'
			elsif an < 1
				'%.4f'
			elsif an < 1000
				'%.2f'
			elsif an < 100000
				'%.1f'
			else
				'%.4g'
			end
		s = fmt % [number]
    # Remove trailing 0
    if fmt[-1] == 'f'
      s.gsub(/\.?0+$/, '')
    else
      s
    end
	else
		number.to_s
	end
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

def redirect_to(io)
	saved_stdout = $stdout
	$stdout = io
	yield
ensure
	$stdout = saved_stdout
end

def pager(&b)
	pager_prog = ENV['PAGER'] || "/usr/bin/less"
	IO.popen(pager_prog, "w") { |io|
		redirect_to io, &b
	}
end

def redirect_to_file(*args, &b)
	if args.empty?
		args = ['stdout.txt', 'w']
	end
	File.open(*args) { |f|
		redirect_to f, &b
	}
end

def redirect_to_string(&b)
	StringIO.open("", "w") { |so|
		redirect_to so, &b
		so.string
	}
end

def monitor_file(file, history = 10)
	system "tail", "-f", "-n", history.to_s, file
end

def xzopen(fn, mode = "r", &blk)
  sfn = fn[0, fn.size - 3]
  if File.exist?(sfn)
    File.open(sfn, mode, &blk)
  else
    IO.popen("xzcat #{fn}", mode, &blk)
  end
end

## Date and time

ONE_DAY = 60 * 60 * 24
DATE_GLOB = '????-??-??'.freeze

def str_date(t)
	t.strftime('%F')
end

def date_of_time(t)
	Time.new t.year, t.month, t.day
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

def mkdir_p(dir, mode = 02775)
	FileUtils.mkdir_p dir, :mode => mode
end

def with_flock(lock_file)
	File.open(lock_file, File::RDWR|File::CREAT, 0664) { |f|
		f.flock(File::LOCK_EX)
		yield
	}
end

def with_flock_timeout(lock_file, timeout)
	File.open(lock_file, File::RDWR|File::CREAT, 0664) { |f|
		Timeout::timeout(timeout) {
			f.flock(File::LOCK_EX)
		}
		yield
	}
end

def delete_file_if_exist(file)
	File.exist?(file) and File.delete(file)
end

LOCAL_RUN_ENV="LKP_LOCAL_RUN"

def local_run?
	ENV[LOCAL_RUN_ENV]
end

def set_local_run
	ENV[LOCAL_RUN_ENV] = "1"
end
