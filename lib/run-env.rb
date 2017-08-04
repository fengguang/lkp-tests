#!/usr/bin/env ruby
LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath(__FILE__)))
LOCAL_RUN_ENV = 'LKP_LOCAL_RUN'.freeze

require 'yaml'

def __local_run?
  hostname = `hostname`.chomp
  return false unless File.exist?("#{LKP_SRC}/hosts/#{hostname}")
  host_file = YAML.load_file("#{LKP_SRC}/hosts/#{hostname}")
  host_file['local_run'] == 1
end

def local_run?
  env_is_local = ENV[LOCAL_RUN_ENV]
  if env_is_local != '1' && env_is_local != '0'
    env_is_local = __local_run? ? '1' : '0'
    ENV[LOCAL_RUN_ENV] = env_is_local
  end
  env_is_local == '1'
end

def git_root_dir
  ENV['GIT_ROOT_DIR'] ||= local_run? ? '/lkp/repo' : '/c/repo'
end

def result_prefix
  ENV['RESULT_PREFIX'] ||= local_run? ? '/lkp' : ''
end

def set_local_run
  ENV[LOCAL_RUN_ENV] = '1'
end
