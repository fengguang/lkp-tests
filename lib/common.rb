# common utilities

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
