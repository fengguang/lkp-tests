#!/usr/bin/ruby

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
		git = Git.open(project: project, working_dir: ENV['SRC_ROOT'])
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

def axis_gcommit(axis_key, value)
	git = axis_key_git(axis_key)
	if git
		[axis_key, git.gcommit(value).sha]
	else
		[axis_key, value]
	end
end

def axes_gcommit(axes)
	naxes = {}
	axes.each { |k, v|
		k, v = axis_gcommit(k, v)
		naxes[k] = v
	}
	naxes
end

