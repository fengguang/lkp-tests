#!/usr/bin/ruby

require 'set'

GIT_TREE ||= ENV['GIT_WORK_TREE'] || '/c/lkp/linux'
GIT	 ||= "git --work-tree=#{GIT_TREE} --git-dir=#{GIT_TREE}/.git"

def commit_tag(commit)
	`#{GIT} tag --points-at #{commit} | grep -v '/' | grep -E '^(v[0-9]|next)'`.chomp
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

def git_committer_name(commit)
	`#{GIT} log -n1 --pretty=format:'%cn' #{commit}`.chomp
end

def is_linus_commit(commit)
	git_committer_name(commit) == 'Linus Torvalds'
end

def linus_release_tag(commit)
	return nil unless is_linus_commit(commit)

	tag = commit_tag(commit)
	case tag
	when /^v[34]\.\d+(|-rc\d+)$/, /^v2\.\d+\.\d+(|-rc\d)$/
		tag
	else
		nil
	end
end

def git_commit(commit)
	`#{GIT} rev-list -n1 #{commit}`.chomp
end

def git_commit_author(commit)
	`#{GIT} log -n1 --pretty=format:'%an <%ae>' #{commit}`.chomp
end

def git_committer(commit)
	`#{GIT} log -n1 --pretty=format:'%cn <%ce>' #{commit}`.chomp
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

# v2.6.32	=> 263200
# v3.11-rc6	=> 301006
# v3.11		=> 301100
def tag_order(tag)
	case tag
	when /^v2\.(\d+)\.(\d+)/
		sort_key = 200000 + $1.to_i * 10000 + $2.to_i * 100
	when /^v3\.(\d+)/
		sort_key = 300000 + $1.to_i * 100
	else
		STDERR.puts "Invalid tag #{tag}"
		return 0
	end

	if tag =~ /-rc(\d+)$/
		sort_key += $1.to_i
		sort_key -= 100
	end

	return sort_key
end

# => ["v3.11-rc6", "v3.11-rc5", "v3.11-rc4", "v3.11-rc3", "v3.11-rc2", "v3.11-rc1",
#     "v3.10", "v3.10-rc7", "v3.10-rc6", ..., "v2.6.12-rc3", "v2.6.12-rc2", "v2.6.11"]
def linus_tags()
	tags = []
	`#{GIT} tag -l 'v*.*'`.each_line { |tag|
		tag.chomp!
		tags << tag if tag =~ /^(v2\.\d+|v3)\.\d+(-rc\d+)?$/
	}
	tags.sort_by { |tag| - tag_order(tag) }
end

# if commit has a version tag, return it directly;
# otherwise checkout commit and get latest version from Makefile.
def last_linus_release_tag(commit)
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

	if version == 3
		tag = "v3.#{patch_level}"
	elsif version == 2
		tag = "v2.#{patch_level}.#{sub_level}"
	else
		STDERR.puts "Not a kernel tree? check #{GIT_TREE}"
		STDERR.puts caller.join "\n"
		return nil
	end

	tag += "-rc#{rc}" if rc and rc > 0
	return [tag, false]
end

def base_rc_tag(commit)
	commit += '~' if is_linus_commit(commit)
	version, is_exact_match = last_linus_release_tag commit
	return version
end
