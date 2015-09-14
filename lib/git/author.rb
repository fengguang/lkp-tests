LKP_SRC ||= ENV["LKP_SRC"] || File.dirname(File.dirname File.realpath $PROGRAM_NAME)

require "#{LKP_SRC}/lib/simple_cache_method"
require 'git'

module Git
	class Author
		def formatted_name
			"#{@name} <#{@email}>"
		end
	end
end