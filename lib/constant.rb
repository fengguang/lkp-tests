#!/usr/bin/env ruby
LKP_SRC ||= ENV['LKP_SRC']

require "#{LKP_SRC}/lib/constant-shared.rb"

DEVEL_HOURLY_KCONFIGS = ['x86_64-rhel']
GIT_ROOT_DIR = '/c/repo'