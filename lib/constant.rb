#!/usr/bin/env ruby
LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)
LKP_USER ||= ENV['LKP_USER'] || ENV['USER'] || `whoami`.chomp

require "#{LKP_SRC}/lib/run_env"

DEVEL_HOURLY_KCONFIGS = %w(x86_64-rhel-7.6).freeze
GIT_ROOT_DIR = git_root_dir

TESTCASE_AXIS_KEY = 'testcase'.freeze
COMMIT_AXIS_KEY = 'commit'.freeze
TBOX_GROUP_AXIS_KEY = 'tbox_group'.freeze

KERNEL_ROOT = '/pkg/linux'.freeze
KTEST_USER_GENERATED_DIR = "/lkp/user-generated".freeze
