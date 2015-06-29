LKP_SRC ||= ENV['LKP_SRC']

require "#{LKP_SRC}/lib/common.rb"
require "#{LKP_SRC}/lib/lkp_git"
require "#{LKP_SRC}/lib/git-tag.rb"
git_update_rb = "#{LKP_SRC}/lib/git-update.rb"
require git_update_rb if File.exists? git_update_rb

class Commit < Git::Object::Commit
	def initialize(commit)
		# TODO pass real project info to project_init
		git = Git.project_init
		super(git, commit)
	end

	def author
		super.author.formatted_name
	end

	def base_tag
		@base_tag ||= Commit.tag_finder.last_release_tag(self.sha)
	end
end

class << Commit
	include SimpleCacheMethod

	def open(commit, branch = nil)
		git_update branch if branch
		lcommit = git_commit commit
		unless is_commit lcommit
			raise ArgumentError, "Invalid commit: #{commit}"
		end

		self.new(lcommit)
	end

	cache_method :open

	def open_branch(branch)
		git_update branch
		commit = git_commit branch
		unless is_commit commit
			raise ArgumentError, "Invalid branch: #{branch}"
		end

		self.new(commit)
	end

	def tag_finder
		@tag_finder ||= GitTag.new(remote:"default")
	end
end
