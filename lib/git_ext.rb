#!/usr/bin/env ruby

LKP_SRC ||= ENV["LKP_SRC"] || File.dirname(File.dirname File.realpath $PROGRAM_NAME)

require 'set'
require 'time'
require 'git'
require "#{LKP_SRC}/lib/yaml.rb"
require "#{LKP_SRC}/lib/cache"
require "#{LKP_SRC}/lib/assert"
require "#{LKP_SRC}/lib/git_ext/base"
require "#{LKP_SRC}/lib/git_ext/object"
require "#{LKP_SRC}/lib/git_ext/lib"
require "#{LKP_SRC}/lib/git_ext/author"
require "#{LKP_SRC}/lib/git_ext/cache"
require "#{LKP_SRC}/lib/constant"

module Git
	class << self
		# init a repository
		#
		# options
		#		:project     => 'project_name', default is linux
		#		:working_dir => 'work_tree_dir', mandatory parameter
		#		:repository  => '/path/to/alt_git_dir', default is '/working_dir/.git'
		#		:index       => '/path/to/alt_index_file', default is '/working_dir/.git/index'
		#
		# example
		#		Git.init({project: 'dpdk',working_dir: '/c/repo/dpdk'})
		#
		alias_method :orig_init, :init
		def init(options = {})
			assert(options[:project], "Git.init: options[:project] can't be #{options[:project].inspect}")

			working_dir = options[:working_dir] || "#{GIT_ROOT_DIR}/#{options[:project]}"

			Git.orig_init(working_dir, options)
		end

		#
		# open an existing repository
		#
		alias_method :orig_open, :open
		def open(options = {})
			assert(options[:project], "Git.open: options[:project] can't be #{options[:project].inspect}")

			working_dir = options[:working_dir] || "#{GIT_ROOT_DIR}/#{options[:project]}"

			if options[:may_not_exist] && !Dir.exist?(working_dir)
				return nil
			end

			Git.orig_open(working_dir, options)
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
	end
end
