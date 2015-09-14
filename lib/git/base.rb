LKP_SRC ||= ENV["LKP_SRC"] || File.dirname(File.dirname File.realpath $PROGRAM_NAME)

require "#{LKP_SRC}/lib/simple_cache_method"
require 'git'

module Git
	class Base
		include SimpleCacheMethod

		cache_method :gcommit, ->obj {obj.project}
		alias_method :orig_initialize, :initialize

		attr_reader :project

		def initialize(options = {})
			orig_initialize(options)
			@project = options[:project]
		end

		# add tag_names because Base::tags is slow to obtain all tag objects
		# FIXME consider to cache this method
		def tag_names
			lib.tag('-l').split("\n")
		end

		def commit_exist?(commit)
			lib.orig_command('rev-list', ['-1', commit])
		rescue
			false
		else
			true
		end

		def default_remote
			# FIXME remove ENV usage
			# TODO abstract File.dirname(File.dirname logic
			lkp_src = ENV["LKP_SRC"] || File.dirname(File.dirname File.realpath $PROGRAM_NAME)

			load_yaml(lkp_src + "/repo/#{@project}/DEFAULTS")
		end

		def release_tags
			pattern = Regexp.new '^' + default_remote['release_tag_pattern'].sub(' ', '$|^') + '$'
			self.tag_names.select {|tag_name| pattern.match(tag_name)}
		end

		def release_tags_with_order
			pattern = Regexp.new '^' + default_remote['release_tag_pattern'].sub(' ', '$|^') + '$'

			tags = sort_tags(pattern, self.release_tags)

			Hash[tags.map.with_index {|tag, i| [tag, -i]}]
		end

		def release_shas
			release_tags.map {|release_tag| lib.command('rev-list', ['-1', release_tag])}
		end

		def release_tags2shas
			tags = release_tags
			shas = release_shas
			tags2shas = {}
			tags.each_with_index {|tag, i| tags2shas[tag] = shas[i]}
			tags2shas
		end

		def release_shas2tags
			tags = release_tags
			shas = release_shas
			shas2tags = {}
			shas.each_with_index {|sha, i| shas2tags[sha] = tags[i]}
			shas2tags
		end

		cache_method :release_tags, ->obj {obj.project}
		cache_method :release_tags_with_order, ->obj {obj.project}
		cache_method :release_shas, ->obj {obj.project}
		cache_method :release_tags2shas, ->obj {obj.project}
		cache_method :release_shas2tags, ->obj {obj.project}

		def release_tag_order(tag)
			release_tags_with_order[tag]
		end
	end
end
