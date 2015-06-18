#!/usr/bin/env ruby

require 'set'
require 'time'
require 'git'

LKP_SRC ||= ENV["LKP_SRC"] || File.dirname(File.dirname File.realpath $PROGRAM_NAME)

GIT_WORK_TREE	||= ENV['GIT_WORK_TREE'] || ENV['LINUX_GIT'] || '/c/repo/linux'
GIT_DIR		||= ENV['GIT_DIR'] || GIT_WORK_TREE + '/.git'
GIT		||= "git --work-tree=#{GIT_WORK_TREE} --git-dir=#{GIT_DIR}"

require "#{LKP_SRC}/lib/yaml.rb"

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

			@caches ||= {}
			@cache_key_prefix_generators ||= {}

			@cache_key_prefix_generators[method_name] = cache_key_prefix_generator

			# FIXME rli9 do not support &block and complex args like Array
			# FIXME rli9 better solution for generating key can refer to
			# https://github.com/seamusabshere/cache_method/blob/master/lib/cache_method.rb
			define_method(method_name) do |*args|
				kclass = (self.instance_of?(Class) || self.instance_of?(Module)) ? self.singleton_class : self.class

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

module Git
	class Base
		include SimpleCacheMethod

		cache_method :gcommit

		# add tag_names because Base::tags is slow to obtain all tag objects
		# FIXME consider to cache this method
		def tag_names
			lib.tag('-l').split("\n")
		end
	end

	class Lib
		public
		def command_lines(cmd, opts = [], chdir = true, redirect = '')
			command_lines = command(cmd, opts, chdir)
			begin
				command_lines.split("\n")
			rescue
				STDERR.puts "Git error: #{cmd} #{opts}"

				STDERR.puts "GIT ENV: LANG = #{ENV['LANG']}, LANGUAGE = #{ENV['LANGUAGE']}, LC_ALL = #{ENV['LC_ALL']}"
				STDERR.puts "GIT string: encoding = #{command_lines.encoding}, "\
				            "scrub = #{command_lines == command_lines.scrub}, "\
				            "utf8 = #{command_lines == command_lines.encode("UTF-8", "UTF-8", invalid: :replace, undef: :replace)}"

				command_lines.encode("UTF-8", "binary", invalid: :replace, undef: :replace).split("\n")
			end
		end
	end

	class Author
		# FIXME need better name
		def formatted_name
			"#{@name} <#{@email}>"
		end
	end

	class Object
		class Commit
			include SimpleCacheMethod

			def subject
				self.message.split("\n").first
			end

			def tags
				check_commit
				@tags ||= @base.lib.tag('--points-at', @sha).split
			end

			def parent_shas
				@parent_shas ||= self.parents.map {|commit| commit.sha}
			end

			# FIXME need better name
			def interested_tag(options = {})
				project_tags = Git.project_tags(options)
				tags.find {|tag| project_tags.include? tag} || tags.first
			end

			# FIXME one alternative is to put this as Git class method
			# FIXME consider to store project information to base when init git
			# options
			#	  :committer => 'committer_name', default is 'Linus Torvalds'
			#
			def release_tag(options = {})
				options[:committer] ||= 'Linus Torvalds'

				if committer.name == options[:committer]
					tag = self.interested_tag(options)
					# FIXME abstract to a function and mapped from project
					tag if tag && (tag.match(/^v[34]\.\d+(-rc\d+)?$/) || tag.match(/^v2\.\d+\.\d+(-rc\d)?$/))
				end
			end

			#
			# if commit has a version tag, return it directly;
			# otherwise checkout commit and get latest version from Makefile.
			#
			def base_release_tag(options = {})
				tag = release_tag(options)
				return [tag, true] if tag =~ /^v.*/

				version = patch_level = sub_level = rc = nil

				@base.lib.command_lines('show', "#{@sha}:Makefile").each do |line|
					case line
					when /VERSION *= *(\d+)/
						version = $1.to_i
					when /PATCHLEVEL *= *(\d+)/
						patch_level = $1.to_i
					when /SUBLEVEL *= *(\d+)/
						sub_level = $1.to_i
					when /EXTRAVERSION *= *-rc(\d+)/
						rc = $1.to_i
					else
						break
					end
				end

				if version && version >= 2
					tag = "v#{version}.#{patch_level}"
					tag += ".#{sub_level}" if version ==2
					tag += "-rc#{rc}" if rc && rc > 0

					[tag, false]
				else
					STDERR.puts "Not a kernel tree? Check #{@base.repo}"
					STDERR.puts caller.join "\n"

					nil
				end
			end

			cache_method :interested_tag, ->(obj) {obj.to_s}
			cache_method :base_release_tag, ->(obj) {obj.to_s}
		end
	end

	class << self
		include SimpleCacheMethod

		# this is not exactly equal to use GIT_WORK_TREE/GIT_DIR that is
		# evaluated at "require statement", instead the function is evaluated at each call.
		# TODO furture refactoring such as caching
		# TODO move the ENV evaluation resposibility to caller or another helper function
		# TODO deduce project from branch

		# init a repository
		#
		# options
		#		:project => 'project_name', default is linux
		#		:repository => '/path/to/alt_git_dir', default is '/working_dir/.git'
		#
		# example
		#		Git.project_init(project: 'dpdk')
		#		Git.project_init(repository: '/path/to/alt_git_dir')
		#
		def project_init(options = {})
			options[:project] ||= 'linux'
			options[:repository] ||= ENV['GIT_DIR']

			working_dir = ENV['GIT_WORK_TREE'] || ENV['LINUX_GIT'] || "/c/repo/#{options[:project]}"

			Git.init(working_dir, options)
		end

		#
		# options
		#	  :project => 'project_name', default is linux
		#	  :remote => 'remote_name', default is 'linus'
		#
		def project_tags(options = {})
			options[:project] ||= 'linux'
			# FIXME remote default need be mapped from project
			options[:remote] ||= 'linus'

			# FIXME consider to check whether project_remote is nil
			project_remote = project_remotes(options)[options[:remote]]

			pattern = Regexp.new '^' + project_remote['release_tag_pattern'].sub(' ', '$|^') + '$'

			tags = select_tags(pattern, project_remote['release_tag_committer'], project: options[:project])
			tags = sort_tags(pattern, tags)

			Hash[tags.map.with_index {|tag, i| [tag, -i]}]
		end

		# FIXME remove ENV usage
		# FIXME to design default project as * or linux
		def project_remotes(options = {})
			lkp_src = ENV["LKP_SRC"] || File.dirname(File.dirname File.realpath $PROGRAM_NAME)

			options[:project] ||= '*'

			remotes = {}

			Dir[lkp_src + "/repo/#{options[:project]}/*"].each do |file|
				remote = File.basename file
				next if remote == 'DEFAULTS'

				defaults = File.dirname(file) + '/DEFAULTS'
				remotes[remote] = load_yaml_merge [defaults, file]
			end

			remotes
		end

		cache_method :project_tags
		cache_method :project_remotes

		private
		def select_tags(pattern, committer, options)
			git = Git.project_init(project: options[:project])

			git.tag_names.map {|tag_name| tag_name.chomp}
			             .select {|tag_name| pattern.match(tag_name)}
		end
	end
end

def __commit_tag(commit)
	tags = `#{GIT} tag --points-at #{commit}`.split
	tags.each do |tag|
		return tag if linus_tags.include? tag
	end
	return tags[0]
end

def commit_tag(commit)
	$__commit_tag_cache ||= {}
	return $__commit_tag_cache[commit] if $__commit_tag_cache.include?(commit)
	return $__commit_tag_cache[commit] = __commit_tag(commit)
end

def commit_name(commit)
	tag = commit_tag(commit)
	return tag if tag
	return commit
end

def is_commit(commit)
	commit =~ /^[0-9a-f~^]{7,}$/ or
	commit =~ /^v[234]\.\d+/
end

def expand_possible_commit(s)
	return s unless is_commit s
	return s unless commit_exists s
	return git_commit s
end

def git_parent_commits(commit)
	`#{GIT} log -n1 --format=%P #{commit}`.chomp.split(' ')
end

def __git_committer_name(commit)
	`#{GIT} log -n1 --pretty=format:'%cn' #{commit}`.chomp
end

def git_committer_name(commit)
	$__committer_name_cache ||= {}
	$__committer_name_cache[commit] ||= __git_committer_name(commit)
	return $__committer_name_cache[commit]
end

def is_linus_commit(commit)
	git_committer_name(commit) == 'Linus Torvalds'
end

def linus_release_tag(commit)
	return nil unless is_linus_commit(commit)

	tag = commit_tag(commit)
	case tag
	when /^v[34]\.\d+(-rc\d+)?$/, /^v2\.\d+\.\d+(-rc\d)?$/
		tag
	else
		nil
	end
end

def is_sha1_40(commit)
	commit.size == 40 and commit =~ /^[0-9a-f]+$/
end

def git_commit(commit)
	return commit if is_sha1_40(commit)

	$__git_commit_cache ||= {}
	return $__git_commit_cache[commit] if $__git_commit_cache.include?(commit)
	sha1_commit = `#{GIT} rev-list -n1 #{commit}`.chomp
	$__git_commit_cache[commit] = sha1_commit unless sha1_commit.empty?
	return sha1_commit
end

def git_commit_author(commit)
	`#{GIT} log -n1 --pretty=format:'%an <%ae>' #{commit}`.chomp
end

def git_committer(commit)
	`#{GIT} log -n1 --pretty=format:'%cn <%ce>' #{commit}`.chomp
end

def git_commit_time(commit)
	scdate = `#{GIT} log -n1 --pretty=format:'%cD' #{commit}`.chomp
	Time.rfc822 scdate
end

def commit_exists(commit)
	return false unless commit

	$commits_set ||= Set.new
	return true if $commits_set.include? commit

	if system "#{GIT} rev-parse --quiet --verify '#{commit}^{commit}' >/dev/null 2>/dev/null"
		$commits_set.add commit
		return true
	end

	return false
end

def compare_version(aa, bb)
	aa.names.each do |name|
		aaa = aa[name]
		bbb = bb[name]
		next if aaa == bbb
		if name =~ /prerelease/
			direction = -1
		else
			direction = 1
		end
		if aaa and bbb
			unless name =~ /str|name/
				aaa = aaa.to_i
				bbb = bbb.to_i
			end
			return aaa <=> bbb
		elsif aaa and !bbb
			return direction
		elsif !aaa and bbb
			return -direction
		end
	end
	return 0
end

def sort_tags(pattern, tags)
	tags.sort do |a, b|
		aa = pattern.match a
		bb = pattern.match b
		-compare_version(aa, bb)
	end
end

def get_tags(pattern, committer)
	tags = []
	`#{GIT} tag -l`.each_line { |tag|
		tag.chomp!
		next unless pattern.match(tag)
		# disabled: too slow and lots of git lead to OOM
		# next unless committer == nil or committer == git_committer_name(tag)
		tags << tag
	}
	tags
end

# => ["v3.11-rc6", "v3.11-rc5", "v3.11-rc4", "v3.11-rc3", "v3.11-rc2", "v3.11-rc1",
#     "v3.10", "v3.10-rc7", "v3.10-rc6", ..., "v2.6.12-rc3", "v2.6.12-rc2", "v2.6.11"]
def __linus_tags()
	$remotes ||= load_remotes
	pattern = Regexp.new '^' + $remotes['linus']['release_tag_pattern'].sub(' ', '$|^') + '$'
	tags = get_tags(pattern, $remotes['linus']['release_tag_committer'])
	tags = sort_tags(pattern, tags)
	tags_order = {}
	tags.each_with_index do |tag, i|
		tags_order[tag] = -i
	end
	tags_order
end

def tag_order(tag)
	linus_tags[tag]
end

def linus_tags()
	$__linus_tags_cache ||= __linus_tags
	return $__linus_tags_cache
end

# if commit has a version tag, return it directly;
# otherwise checkout commit and get latest version from Makefile.
def __last_linus_release_tag(commit)
	tag = linus_release_tag commit
	return [tag, true] if tag =~ /^v.*/

	version = patch_level = sub_level = rc = nil

	`#{GIT} show #{commit}:Makefile`.each_line { |line|
		case line
		when /VERSION *= *(\d+)/
			version = $1.to_i
		when /PATCHLEVEL *= *(\d+)/
			patch_level = $1.to_i
		when /SUBLEVEL *= *(\d+)/
			sub_level = $1.to_i
		when /EXTRAVERSION *= *-rc(\d+)/
			rc = $1.to_i
		else
			break
		end
	}

	if version and version >= 3
		tag = "v#{version}.#{patch_level}"
	elsif version == 2
		tag = "v2.#{patch_level}.#{sub_level}"
	else
		STDERR.puts "Not a kernel tree? check #{GIT_WORK_TREE}"
		STDERR.puts caller.join "\n"
		return nil
	end

	tag += "-rc#{rc}" if rc and rc > 0
	return [tag, false]
end

def last_linus_release_tag(commit)
	$__last_linus_tag_cache ||= {}
	$__last_linus_tag_cache[commit] ||= __last_linus_release_tag(commit)
	return $__last_linus_tag_cache[commit]
end

def base_rc_tag(commit)
	commit += '~' if is_linus_commit(commit)
	version, is_exact_match = last_linus_release_tag commit
	return version
end

def version_tag(commit)
	tag, is_exact_match = last_linus_release_tag(commit)
	return nil unless tag

	tag += '+' unless is_exact_match
	return tag
end

def load_remotes
	remotes = {}
	files = Dir[LKP_SRC + '/repo/*/*']
	files.each do |file|
		remote = File.basename file
		next if remote == 'DEFAULTS'
		defaults = File.dirname(file) + '/DEFAULTS'
		remotes[remote] = load_yaml_merge [defaults, file]
	end
	remotes
end
