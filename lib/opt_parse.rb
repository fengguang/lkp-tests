#!/usr/bin/env ruby

require 'optparse'


# if pass a unknow option to ruby's OptionParser, it will throw OptionParser::InvalidOption
# solution refer to: https://stackoverflow.com/questions/3642331/can-optionparser-skip-unknown-options-to-be-processed-later-in-a-ruby-program
#
# we define switch "-h" and "-d" in the script $LKP_SRC/sbin/cci.rb
# but we use: cci.rb -h -s s1 ("-s" is not defined)
# cci.rb will parse ARGV(-h), and after parse ARGV is "-s s1"   
class OptionParser
  def parser_with_unknow_args!(args)
    skip_opts = []
    begin
      # this collect unknow args without '-/--' prefix
      order!(args) { |a| skip_opts << a }
    rescue OptionParser::InvalidOption => e
      # this collect unknow args with '-/--' prefix
      skip_opts << e.args[0]
      retry
    end
    # insert skip_opts into args's beginning
    args[0, 0] = skip_opts
  end
end
