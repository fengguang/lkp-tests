# common utilities

def deepcopy(o)
	Marshal.load(Marshal.dump(o))
end

# Cache the instances of the class
class Cached
end

class << Cached
	def cached_new(key, *args)
		@cache ||= {}
		@cache[key] or @cache[key] = new(*args)
	end
end
