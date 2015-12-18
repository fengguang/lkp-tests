#!/usr/bin/env ruby

LKP_SRC ||= ENV["LKP_SRC"] || File.dirname(File.dirname File.realpath $PROGRAM_NAME)

# Note! require 'git' will reset ENV GIT_WORK_TREE/GIT_DIR
GIT_WORK_TREE	||= ENV['GIT_WORK_TREE'] || ENV['LINUX_GIT'] || '/c/repo/linux'
GIT_DIR		||= ENV['GIT_DIR'] || GIT_WORK_TREE + '/.git'
GIT		||= "git --work-tree=#{GIT_WORK_TREE} --git-dir=#{GIT_DIR}"

require 'set'
require 'time'
require 'git'

require "#{LKP_SRC}/lib/yaml.rb"
require "#{LKP_SRC}/lib/cache"
require "#{LKP_SRC}/lib/assert"

require "#{LKP_SRC}/lib/git/base"
require "#{LKP_SRC}/lib/git/object"
require "#{LKP_SRC}/lib/git/lib"
require "#{LKP_SRC}/lib/git/author"
require "#{LKP_SRC}/lib/git/cache"

$work_tree_base_dir = '/c/repo'

module Git
	class << self
		# TODO move the ENV evaluation resposibility to caller or another helper function
		# TODO deduce project from branch
		# init a repository
		#
		# options
		#		:project => 'project_name', default is linux
		#		:repository => '/path/to/alt_git_dir', default is '/working_dir/.git'
		#
		# example
		#		Git.init(project: 'dpdk')
		#		Git.init(repository: '/path/to/alt_git_dir')
		#
		alias_method :orig_init, :init
		def init(options = {})
			options[:project] ||= 'linux'

			working_dir = options[:working_dir] || ENV['SRC_ROOT'] || project_work_tree(options[:project])

			Git.orig_init(working_dir, options)
		end

		#
		# open an existing repository
		#
		alias_method :orig_open, :open
		def open(options = {})
			assert(options[:project], "options[:project] can't be #{options[:project].inspect}")

			working_dir = options[:working_dir] || ENV['SRC_ROOT'] || project_work_tree(options[:project])

			Git.orig_open(working_dir, options)
		end

		def project_exist?(project)
			Dir.exist? project_work_tree(project)
		end

		def linux_last_release_tag_strategy(git_base, commit_sha)
			version = patch_level = sub_level = rc = nil

			git_base.lib.command_lines('show', "#{commit_sha}:Makefile").each do |line|
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
				$stderr.puts "Not a kernel tree? Check #{@base.repo}"
				$stderr.puts caller.join "\n"

				nil
			end
		end

		# FIXME remove ENV usage
		# load remotes information from config files
		#
		# options
		#		:project => 'project_name', default is linux
		#
		def remote_descs(options = {})
			lkp_src = ENV["LKP_SRC"] || File.dirname(File.dirname File.realpath $PROGRAM_NAME)

			options[:project] ||= '*'
			options[:remote] ||= '*'

			remotes = {}

			Dir[File.join(lkp_src, "repo", options[:project], options[:remote])].each do |file|
				remote = File.basename file
				next if remote == 'DEFAULTS'

				defaults = File.dirname(file) + '/DEFAULTS'
				remotes[remote] = load_yaml_merge [defaults, file]
			end

			remotes
		end

		def remote_desc(options = {})
			assert(options[:remote], "options[:remote] parameter can't be #{options[:remote].inspect}")

			remote_descs(options)[options[:remote]]
		end

		def sha1_40?(commit)
			commit =~ /^[\da-f]{40}$/
		end

		def commit_name?(commit_name)
			commit_name =~ /^[\da-f~^]{7,}$/ ||
			commit_name =~ /^v[234]\.\d+/ ||
			sha1_40?(commit_name)
		end
	end
end

def project_work_tree(project)
	File.join $work_tree_base_dir, project
end

def expand_possible_commit(s)
	return s unless Git.commit_name? s

	git = Git.open(project: 'linux')
	return s unless git.commit_exist? s
	return git.gcommit(s).sha
end

def linux_commit(c)
	git = Git.open(project: 'linux')
	git.gcommit(c)
end

def linux_commits(*commits)
	git = Git.open(project: 'linux')
	commits.map { |c| git.gcommit(c) }
end

def axis_key_project(axis_key)
	case axis_key
	when 'commit'
		'linux'
	when 'head_commit', 'base_commit'
		'linux'
	when /_commit$/
		axis_key.sub(/_commit$/, '')
	end
end

def axis_key_git(axis_key)
	project = axis_key_project(axis_key)
	if project
		Git.open(project: project)
	end
end

def axis_format(axis_key, value)
	git = axis_key_git(axis_key)
	if git
		tag = git.gcommit(value).tags.first
		if tag
			[axis_key, tag]
		else
			[axis_key, value]
		end
  else
		[axis_key, value]
	end
end

def commits_to_string(commits)
	commits.map { |c| c.to_s }
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

def git_commit(commit)
	return commit if Git.sha1_40?(commit)

	$__git_commit_cache ||= {}
	return $__git_commit_cache[commit] if $__git_commit_cache.include?(commit)
	sha1_commit = `#{GIT} rev-list -n1 #{commit}`.chomp
	$__git_commit_cache[commit] = sha1_commit unless sha1_commit.empty?
	return sha1_commit
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
		$stderr.puts "Not a kernel tree? check #{GIT_WORK_TREE}"
		$stderr.puts caller.join "\n"
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

def linus_tags()
	$__linus_tags_cache ||= __linus_tags
	return $__linus_tags_cache
end

def base_rc_tag(commit)
	commit += '~' if is_linus_commit(commit)
	version, is_exact_match = last_linus_release_tag commit
	return version
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
