LKP_SRC ||= ENV["LKP_SRC"] || File.dirname(File.dirname File.realpath $PROGRAM_NAME)

require 'git'

module Git
	class Base
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
			self.command('rev-list', ['-1', commit])
		rescue
			false
		else
			true
		end

		def remote_exist?(remote)
			command('remote') =~ /^#{remote}$/
		end

		def branch_exist?(pattern)
			!command('branch', ['--list', '-a', pattern]).empty?
		end

		def release_tags
			unless @release_tags
				$remotes ||= load_remotes
				pattern = Regexp.new '^' + $remotes[@project]['release_tag_pattern'].sub(' ', '$|^') + '$'
				@release_tags = self.tag_names.select {|tag_name| pattern.match(tag_name)}
			end

			@release_tags
		end

		def release_tags_with_order
			unless @release_tags_with_order
				$remotes ||= load_remotes
				pattern = Regexp.new '^' + $remotes[@project]['release_tag_pattern'].sub(' ', '$|^') + '$'

				tags = sort_tags(pattern, self.release_tags)
				@release_tags_with_order = Hash[tags.map.with_index {|tag, i| [tag, -i]}]
			end

			@release_tags_with_order
		end

		def ordered_release_tags
			release_tags_with_order.map { |tag, order| tag }
		end

		def release_shas
			@release_shas ||= release_tags.map {|release_tag| self.command('rev-list', ['-1', release_tag])}
		end

		def release_tags2shas
			unless @release_tags2shas
				tags = release_tags
				shas = release_shas

				@release_tags2shas = {}
				tags.each_with_index {|tag, i| @release_tags2shas[tag] = shas[i]}
			end

			@release_tags2shas
		end

		def release_shas2tags
			unless @release_shas2tags
				tags = release_tags
				shas = release_shas

				@release_shas2tags = {}
				shas.each_with_index {|sha, i| @release_shas2tags[sha] = tags[i]}
			end

			@release_shas2tags
		end

		def release_tag_order(tag)
			release_tags_with_order[tag]
		end

		def sort_commits(commits)
			scommits = commits.map { |c| c.to_s }
			if scommits.size == 2
				r = self.command('rev-list', ["-n", "1", "^#{scommits[0]}", scommits[1]])
				scommits.reverse! if r.strip.empty?
			else
				r = self.command('rev-list', ['--no-walk', '--topo-order', '--reverse'] + scommits)
				scommits = r.split
			end
			scommits.map { |sc| gcommit sc }
		end

		def command(cmd, opts = [], chdir = true, redirect = '', &block)
			lib.command(cmd, opts, chdir, redirect)
		end

		def command_lines(cmd, opts = [], chdir = true, redirect = '')
			lib.command_lines(cmd, opts, chdir, redirect)
		end
	end
end
