LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'English'
require 'shellwords'

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
  end
end
