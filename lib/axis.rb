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
  return unless project

  Git.open(project: project, may_not_exist: true)
end

def axis_format(axis_key, value)
  git = axis_key_git(axis_key)
  if git
    tag = git.gcommit(value).interested_tag
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
  axes.each do |k, v|
    k, v = axis_gcommit(k, v)
    naxes[k] = v
  end
  naxes
end

# These are not used by other code in the repo,
# however handy for interactive debug sessions.
def linux_commit(commit)
  git = Git.open(project: 'linux')
  git.gcommit(commit)
end

def linux_commits(*commits)
  git = Git.open(project: 'linux')
  commits.map { |c| git.gcommit(c) }
end
