LKP_SRC ||= ENV["LKP_SRC"] || File.dirname(File.dirname File.realpath $PROGRAM_NAME)

require "#{LKP_SRC}/lib/cache"

module Git
	class Base
		include Cacheable

		cache_method :gcommit, ->obj {obj.object_id}
	end
end

module Git
	class Object
		class Commit
			include Cacheable

			cache_method :last_release_tag, ->(obj) {obj.to_s}
		end
	end
end
