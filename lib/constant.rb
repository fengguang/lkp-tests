#!/usr/bin/env ruby
LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require "#{LKP_SRC}/lib/run-env"

DEVEL_HOURLY_KCONFIGS = ['x86_64-rhel-7.2'].freeze
GIT_ROOT_DIR = git_root_dir

TESTCASE_AXIS_KEY = 'testcase'.freeze
COMMIT_AXIS_KEY = 'commit'.freeze
TBOX_GROUP_AXIS_KEY = 'tbox_group'.freeze

KERNEL_ROOT = '/pkg/linux'.freeze
