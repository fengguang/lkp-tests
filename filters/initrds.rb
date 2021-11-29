#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require "#{LKP_SRC}/lib/log"

def check_initrds
  missing_initrds = Array(self['initrds']).reject do |initrd_name|
    initrd_name = "#{initrd_name.tr('_', '-')}.cgz"

    initrd_path = File.join(File.dirname(File.realpath(self['kernel'])), initrd_name)
    File.exist? initrd_path
  end

  raise Job::ParamError, "initrd [#{missing_initrds.join(',')}] not exist in #{File.dirname(File.realpath(self['kernel']))}" unless missing_initrds.empty?
end

check_initrds if self['kernel'] && self['initrds']
