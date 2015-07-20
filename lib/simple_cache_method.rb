#
# TODO add usage example
#
module SimpleCacheMethod
	def self.included(mod)
		class << mod
			include ClassMethods
			attr_accessor :caches, :cache_key_prefix_generators
		end
	end

  module ClassMethods
		#
		# cache_key_prefix_generator - customized key prefix generator, possible values
		#   default => share cache between all objects belong to same class
		#   ->(obj) {obj.class.to_s} => same effect as default
		#   ->(obj) {obj.to_s} => share cache between objects who has same to_s
		#   ->(obj) {obj.object_id} => do not share cache between objects
		#
		def cache_method(method_name, cache_key_prefix_generator = nil)
			# credit to rails alias_method_chain
			alias_method "#{method_name}_without_cache", method_name

			kclass = self

			@caches ||= {}
			@cache_key_prefix_generators ||= {}

			@cache_key_prefix_generators[method_name] = cache_key_prefix_generator

			# FIXME rli9 do not support &block
			# FIXME rli9 better solution for generating key can refer to
			# https://github.com/seamusabshere/cache_method/blob/master/lib/cache_method.rb
			define_method(method_name) do |*args|
				cache_key = kclass.cache_key(self, method_name, *args)

				kclass.caches[cache_key] = self.send("#{method_name}_without_cache", *args) unless kclass.caches.has_key? cache_key
				kclass.caches[cache_key]
			end
		end

		def cache_key(obj, method_name, *args)
			# FIXME rli9 to understand performance impact of different hash key
			#cache_key = [self, method_name, args]
			cache_key = "#{method_name}_#{args.join('_')}"

			cache_key_prefix_generator = @cache_key_prefix_generators[method_name]
			cache_key = "#{cache_key_prefix_generator.call obj}_#{cache_key}" if cache_key_prefix_generator

			cache_key
		end
	end
end
