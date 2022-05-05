#! /usr/bin/env ruby

# frozen_string_literal: true

LKP_SRC = ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require 'yaml'
require "#{LKP_SRC}/lib/opt_parse"

COMMAND_INFO = {
  'submit' => {
    'profile' => 'submit test jobs to the scheduler',
    'path' => "#{LKP_SRC}/sbin/submit",
    'type' => 'external'
  },
  'cancel' => {
    'profile' => 'cancel jobs that have not been consumed',
    'path' => "#{LKP_SRC}/sbin/cancel",
    'type' => 'external'
  },
  'hosts' => {
    'profile' => 'search hosts info from es',
    'path' => "#{LKP_SRC}/sbin/hosts",
    'type' => 'external'
  },
  'jobs' => {
    'profile' => 'search jobs info from es',
    'path' => "#{LKP_SRC}/sbin/jobs",
    'type' => 'external'
  },
  'search' => {
    'profile' => 'search info from server es db by dsl',
    'path' => "#{LKP_SRC}/sbin/search",
    'type' => 'external'
  },
  'select' => {
    'profile' => 'search info from server es db by sql',
    'path' => "#{LKP_SRC}/sbin/select",
    'type' => 'external'
  },

  'lkp-renew' => {
    'profile' => 'prolong the service time of the testbox',
    'path' => "#{LKP_SRC}/sbin/lkp-renew",
    'type' => 'internal'
  },
  'return' => {
    'profile' => 'return current testbox right now',
    'path' => "#{LKP_SRC}/sbin/return",
    'type' => 'internal'
  },
  'doc' => {
    'profile' => 'display the documentations',
    'path' => "#{LKP_SRC}/sbin/doc",
    'type' => 'external'
  }
}.freeze

def show_command(opts, type)
  COMMAND_INFO.each do |command, info|
    next unless info['type'] == type

    opts.separator "    #{command}" + ' ' * (33 - command.size) + info['profile']
  end
end

option_hash = {}
options = OptionParser.new do |opts|
  opts.banner = 'Usage: cci [global options] sub_command [sub_command options] [args]'
  opts.separator ''
  opts.separator 'Global options:'

  opts.on('-h', '--help', 'show this message') do |h|
    option_hash['help'] = h
  end
  opts.on('-d', '--data <data>', 'HTTP POST data, some cci sub_commmand need') do |d|
    d.gsub!('"', '\"')
    option_hash['data'] = d
  end

  opts.separator ''
  opts.separator 'These are common cci commands used in various situations:'
  opts.separator ''
  opts.separator 'work on the internal testbox:'
  show_command(opts, 'internal')
  opts.separator ''
  opts.separator "work on the user's machine:"
  show_command(opts, 'external')
end

if ARGV.empty? || ARGV.length == 1 && (ARGV[0] == '-h' || ARGV[0] == '--help')
  puts(options)
  exit
end

options.parser_with_unknow_args!(ARGV)

opt = ARGV.shift
args = ''
ARGV.each do |a|
  args += "\"#{a}\" "
end

cmd = "#{COMMAND_INFO[opt]['path']} #{args.strip}"
cmd += ' -h'                              unless option_hash['help'].nil?
cmd += " -d \"#{option_hash['data']}\""   unless option_hash['data'].nil?
exec cmd
