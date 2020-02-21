#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(__dir__))

require 'git'

module Git
  class Base
    alias orig_initialize initialize

    attr_reader :project

    def initialize(options = {})
      orig_initialize(options)
      @project = options[:project]
      @remote = options[:remote] || @project
    end

    def project_spec
      $remotes ||= load_remotes

      $remotes[@remote] || $remotes['internal-' + @remote]
    end

    # add tag_names because Base::tags is slow to obtain all tag objects
    # FIXME consider to cache this method
    def tag_names
      lib.tag('-l').split("\n")
    end

    def commit_exist?(commit)
      command('rev-list', ['-1', commit])
    rescue StandardError
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

    def linux_last_release_tag_strategy(commit_sha)
      version = patch_level = sub_level = rc = nil

      command_lines('show', "#{commit_sha}:Makefile").each do |line|
        case line
        when /^#/
          next
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
        tag += ".#{sub_level}" if version == 2
        tag += "-rc#{rc}" if rc && rc > 0

        [tag, false]
      else
        warn "Not a kernel tree? Check #{repo}"
        warn caller.join "\n"

        nil
      end
    end

    def commits_tags
      # rli9 FIXME: consider to move cache logic to caller
      return @commits_tags if @commits_tags && @commits_tags_timestamp && Time.now - @commits_tags_timestamp < 600

      @commits_tags_timestamp = Time.now

      @commits_tags = {}
      command('show-ref', ['--tags']).each_line do |line|
        commit, tag = line.split ' refs/tags/'
        @commits_tags[commit] = tag.chomp if tag
      end

      @commits_tags
    end

    def heads_branches
      return @heads_branches if @heads_branches && @heads_branches_timestamp && Time.now - @heads_branches_timestamp < 600

      @heads_branches_timestamp = Time.now

      @heads_branches = {}
      command('show-ref').each_line do |line|
        commit, branch = line.split ' refs/remotes/'
        @heads_branches[commit] = branch.chomp if branch
      end

      @heads_branches
    end

    def release_tag_pattern
      @release_tag_pattern ||= Regexp.new '^' + Array(project_spec['release_tag_pattern']).join('$|^') + '$'
    end

    def release_tags
      @release_tags ||= tag_names.select { |tag_name| release_tag_pattern.match(tag_name) }
    end

    def release_tags_with_order
      unless @release_tags_with_order
        tags = sort_tags(release_tag_pattern, release_tags)
        @release_tags_with_order = Hash[tags.map.with_index { |tag, i| [tag, -i] }]
      end

      @release_tags_with_order
    end

    def ordered_release_tags
      release_tags_with_order.keys
    end

    def ordered_official_release_tags
      release_tags_with_order.keys.select { |k| k =~ /^v[0-9]*\.[0-9]*(|\.[0-9]*)$/ }
    end

    def release_shas
      @release_shas ||= release_tags.map { |release_tag| command('rev-list', ['-1', release_tag]) }
    end

    def release_tags2shas
      unless @release_tags2shas
        tags = release_tags
        shas = release_shas

        @release_tags2shas = {}
        tags.each_with_index { |tag, i| @release_tags2shas[tag] = shas[i] }
      end

      @release_tags2shas
    end

    def release_shas2tags
      unless @release_shas2tags
        tags = release_tags
        shas = release_shas

        @release_shas2tags = {}
        shas.each_with_index { |sha, i| @release_shas2tags[sha] = tags[i] }
      end

      @release_shas2tags
    end

    def release_tag_order(tag)
      release_tags_with_order[tag]
    end

    def sort_commits(commits)
      scommits = commits.map(&:to_s)
      if scommits.size == 2
        r = command('rev-list', ['-n', '1', "^#{scommits[0]}", scommits[1]])
        scommits.reverse! if r.strip.empty?
      else
        r = command('rev-list', ['--no-walk', '--topo-order', '--reverse'] + scommits)
        scommits = r.split
      end

      scommits.map { |sc| gcommit sc }
    end

    def first_sha
      command('rev-list --reverse HEAD |head -1')
    end

    def command(cmd, opts = [], chdir = true, redirect = '', &block)
      lib.command(cmd, opts, chdir, redirect, &block)
    end

    def command_lines(cmd, opts = [], chdir = true, redirect = '')
      lib.command_lines(cmd, opts, chdir, redirect)
    end
  end
end
