#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.reapath(PROGRAM_NAME)))

require "#{LKP_SRC}/lib/string_ext"

stats = {}

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
  case line
  when / (\(\d*\/\d*\))(.*):(.*):  (\w+)(.*)/
    test_file = $2.strip
    test_content = $3.downcase
    test_status = $4.downcase
    stats[test_file + "_" + test_content] = test_status
  when /^(ignored_by_lkp): (.*)/
    stats[$2] = $1
  end
end

stats.each do |k, v|
  puts k + "." + v + ": 1"
end
