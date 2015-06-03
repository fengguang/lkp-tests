LKP_SRC ||= ENV['LKP_SRC']

## common utilities

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

def string_to_num(str)
	str.index('.') ? str.to_f : str.to_i
end

## Pathname

def ensure_dir(dir)
	dir[-1] == '/' ? dir : dir + '/'
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

def str_date(t)
	t.strftime('%F')
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
