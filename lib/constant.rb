#!/usr/bin/env ruby
LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath(__FILE__)))

require "#{LKP_SRC}/lib/constant-shared.rb"

DEVEL_HOURLY_KCONFIGS = ['x86_64-rhel-7.2']
GIT_ROOT_DIR = '/c/repo'
