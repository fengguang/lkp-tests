LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'English'
require 'shellwords'
require 'open3'

# rli9 FIXME: find a way to combine w/ misc
module Bash
  class BashCallError < StandardError
  end

  class << self
    # http://greyblake.com/blog/2013/09/21/how-to-call-bash-not-shell-from-ruby/
    def call(command, options = {})
      options[:exitstatus] ||= [0]

      output = `bash -c #{Shellwords.escape(command)}`.chomp
      raise Bash::BashCallError, command unless options[:exitstatus].include?($CHILD_STATUS.exitstatus)

      output
    end

    def call2(command)
      stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(command)}")
      raise Bash::BashCallError, "#{command}\n#{stderr}#{stdout}" unless status.success?

      stdout
    end
  end
end
