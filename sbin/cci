#! /usr/bin/env ruby

# frozen_string_literal: true

LKP_SRC = ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require 'optparse'
require 'yaml'

COMMAND_INFO = {
  'submit' => {
    'profile' => 'submit test jobs to the scheduler',
    'path' => "#{LKP_SRC}/sbin/submit",
    'type' => 'external'
  },
  'cancel' =>{
    'profile' => 'cancel jobs that have not been consumed',
    'path' => "#{LKP_SRC}/sbin/cancel",
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
  }
}.freeze

def show_command(opts, type)
  COMMAND_INFO.each do |command, info|
    next unless info['type'] == type

    opts.separator "    #{command}" + ' ' * (33 - command.size) + info['profile']
  end
end

options = OptionParser.new do |opts|
  opts.banner = 'Usage: cci [global options] command [command options] [args]'
  opts.separator ''
  opts.separator 'Global options:'

  opts.on('-h', '--help', 'show this message') do
    puts options
    exit
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

if ARGV.empty?
  puts(options)
  exit
end

options.order!
opt = ARGV.shift

cmd = "#{COMMAND_INFO[opt]['path']} #{ARGV.join(' ')}"
exec cmd
