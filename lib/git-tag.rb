LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname File.realpath $PROGRAM_NAME)

class GitTag

	def initialize(args)
		@base_tags_cache = nil
		@commit_tag_cache = {}

		# TODO: do not hardcode it
		git_work_dir = ENV['GIT_WORK_TREE'] || ENV['LINUX_GIT'] || '/c/lkp/linux'
		@git_cmd = "git --work-tree=#{git_work_dir} --git-dir=#{git_work_dir}/.git"

		load_tag_patterns(args[:remote])
	end

	def release_tag_pattern()
		@tag_patterns['release_tag_pattern']
	end

	def release_tag_pattern_regexp()
		Regexp.new @tag_patterns['release_tag_pattern']
	end

	# return a list of release tags as base for compare
	def base_tags()
		@base_tags_cache || __base_tags
	end

	def commit_tag(commit)
		@commit_tag_cache[commit] || __commit_tag(commit)
	end

	def tag_order(tag)
		ver = Regexp.new(release_tag_pattern).match tag

		major = ver['major'].to_i rescue 0
		minor = ver['minor'].to_i rescue 0
		micro = ver['micro'].to_i rescue 0
		prerelease = ver['prerelease'].to_i rescue 0

		micro -= 1 if prerelease > 0

		prerelease 		+
		(micro * 1000) 		+
		(minor * 1000000) 	+
		(major * 1000000000)
	end

	# return the last release tag for #{commit}.
	#
	# If the tag points to the #{commit} exactly, is_exact_match
	# is set true, otherwise, it's set false.
	def last_release_tag(commit)
		return nil, false unless commit_exists(commit)

		get_last_release_tag(commit)
	end

	def get_last_release_tag(commit)
		if @tag_patterns['get_last_release_tag_brutal_force']
			get_last_release_tag_brutal_force(commit)
		else
			# TODO: this should be linux kernel specific
			last_linus_release_tag(commit)
		end
	end


    private
	def load_tag_patterns(remote)
		if File.exist?("#{LKP_SRC}/lib/git-tag/tag-patterns-#{remote}")
			@tag_patterns = load_yaml "#{LKP_SRC}/lib/git-tag/tag-patterns-#{remote}"
		else
			@tag_patterns = load_yaml "#{LKP_SRC}/lib/git-tag/tag-patterns-default"
		end
	end

	def __base_tags()
		tags = []

		%x[ #{@git_cmd} tag -l ].each_line { |tag|
			tag.chomp!
			tags.push tag if release_tag_pattern_regexp.match(tag)
		}

		@base_tags_cache = tags.sort_by { |tag| - tag_order(tag) }
	end

	def __commit_tag(commit)
		tag = %x[ #{@git_cmd} tag --points-at #{commit} | grep -E '#{release_tag_pattern}' ].chomp
		@commit_tag_cache[commit] = tag
	end

	# Start a brutal force searching for the last_release tag
	# for #{commit}.
	#
	# If the tag points to the #{commit} exactly, is_exact_match
	# is set true, otherwise, it's set false.
	#
	def get_last_release_tag_brutal_force(commit, nr_steps=1000)
		%x[ #{@git_cmd} rev-list -n #{nr_steps} #{commit} ].each_line { |c|
			c.chomp!

			tag = commit_tag(c)
			is_exact_match = c == commit
			return tag, is_exact_match if tag
		}
		return nil, false
	end
end
