#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'set'
require 'time'
require 'git'
require "#{LKP_SRC}/lib/yaml"
require "#{LKP_SRC}/lib/cache"
require "#{LKP_SRC}/lib/assert"
require "#{LKP_SRC}/lib/git_ext/base"
require "#{LKP_SRC}/lib/git_ext/object"
require "#{LKP_SRC}/lib/git_ext/lib"
require "#{LKP_SRC}/lib/git_ext/author"
require "#{LKP_SRC}/lib/git_ext/cache"
require "#{LKP_SRC}/lib/constant"
require "#{LKP_SRC}/lib/run_env"

module Git
  class << self
    # init a repository
    #
    # options
    #    :project     => 'project_name', default is linux
    #    :working_dir => 'work_tree_dir', mandatory parameter
    #    :repository  => '/path/to/alt_git_dir', default is '/working_dir/.git'
    #    :index       => '/path/to/alt_index_file', default is '/working_dir/.git/index'
    #    :remote      => 'remote_name', default is nil
    #
    # example
    #    Git.init(project: 'dpdk', working_dir: "#{GIT_ROOT_DIR}/dpdk")
    #
    alias orig_init init
    def init(options = {})
      assert(options[:project], "Git.init: options[:project] can't be #{options[:project].inspect}")

      working_dir = options[:working_dir] || "#{GIT_ROOT_DIR}/#{options[:project]}"

      Git.orig_init(working_dir, options)
    end

    #
    # open an existing repository
    #
    alias orig_open open
    def open(options = {})
      assert(options[:project], "Git.open: options[:project] can't be #{options[:project].inspect}")

      working_dir = options[:working_dir] || "#{GIT_ROOT_DIR}/#{options[:project]}"

      return nil if options[:may_not_exist] && !Dir.exist?(working_dir)

      Git.orig_open(working_dir, options)
    end

    # rli9 FIXME: remove ENV usage
    # load remotes information from config files
    #
    # options
    #    :project => 'project_name', default is linux
    #
    def remote_descs(options = {})
      lkp_src = ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

      options[:project] ||= '*'
      options[:remote] ||= '*'

      remotes = {}

      Dir[File.join(lkp_src, 'repo', options[:project], options[:remote])].each do |file|
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
  end
end
