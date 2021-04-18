#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(__dir__))

require "#{LKP_SRC}/lib/cache"

module Git
  class Base
    include Cacheable

    cache_method :gcommit, cache_key_prefix_generator: ->(obj) { obj.object_id }
  end
end

module Git
  class Object
    class Commit
      include Cacheable

      cache_method :last_release_tag, cache_key_prefix_generator: ->(obj) { obj.to_s }
    end
  end
end
