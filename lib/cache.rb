LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require "#{LKP_SRC}/lib/log"

module Cacheable
  def self.included(mod)
    class << mod; include ClassMethods; end
  end

  module ClassMethods
    def cache_store
      @cache_store ||= {}
    end

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

      @cache_key_prefix_generators ||= {}
      @cache_key_prefix_generators[method_name] = cache_key_prefix_generator

      # rli9 FIXME: not support &block
      # rli9 FIXME: better solution for generating key can refer to
      # https://github.com/seamusabshere/cache_method/blob/master/lib/cache_method.rb
      define_method(method_name) do |*args|
        cache_key = kclass.cache_key(self, method_name, *args)

        begin
          kclass.cache_fetch(self, method_name, *args)
        rescue StandardError => e
          log_exception e, binding
          send("#{method_name}_without_cache", *args)
        end
      end
    end

    def cache_fetch(obj, method_name, *args)
      cache_key = cache_key(obj, method_name, *args)

      if cache_store.instance_of?(Hash)
        return cache_store[cache_key] if cache_store.key?(cache_key)

        cache_store[cache_key] = obj.send("#{method_name}_without_cache", *args)
      else
        cache_store.fetch cache_key do
          obj.send("#{method_name}_without_cache", *args)
        end
      end
    end

    def cache_key(obj, method_name, *args)
      # rli9 FIXME: to understand performance impact of different hash key
      # cache_key = [self, method_name, args]
      cache_key = "#{method_name}_#{args.join('_')}"

      cache_key_prefix_generator = @cache_key_prefix_generators[method_name]
      cache_key = "#{cache_key_prefix_generator.call obj}_#{cache_key}" if cache_key_prefix_generator

      cache_key
    end
  end
end
