LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'English'
require 'shellwords'

# rli9 FIXME: find a way to combine w/ misc
module Bash
  class BashCallError < StandardError
  end

  class << self
    # http://greyblake.com/blog/2013/09/21/how-to-call-bash-not-shell-from-ruby/
    def call(command)
      output = `bash -c #{Shellwords.escape(command)} 2>&1`.chomp
      raise Bash::BashCallError, "#{command}: #{output}" if $CHILD_STATUS.exitstatus != 0

      output
    end
  end
end
