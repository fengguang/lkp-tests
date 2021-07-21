#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require "#{LKP_SRC}/lib/log"

exit unless self['kernel']
exit unless self['initrds']

missing_initrds = []
Array(self['initrds']).each do |initrd_name|
  initrd_name = "#{initrd_name.tr('_', '-')}.cgz"
  initrd_path = File.join(File.dirname(File.realpath(self['kernel'])), initrd_name)
  next if File.exist? initrd_path

  missing_initrds << initrd_name
end

raise Job::ParamError, "initrd [#{missing_initrds.join(',')}] not exist in #{File.dirname(File.realpath(self['kernel']))}" unless missing_initrds.empty?
