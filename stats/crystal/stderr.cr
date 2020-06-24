#!/usr/bin/env crystal

require "../../lib/dmesg"
require "../../lib/string_ext"
require "../../lib/log"

error_ids = {} of String => String 

line_str = ""
Dir["#{LKP_SRC}/etc/ignore-stderr/*"].each do |f|
  File.open(f).each_line do |line|
    line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
    line_str = line.to_s
  end
end

def should_ignore_stderr(line,line_str)
  if line
    line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
    ignore_patterns = Regex.new("^" + line_str + "$")
    # ERR in `match': invalid byte sequence in US-ASCII (ArgumentError)
    # treat unrecognized line as "can't be ignored"
      begin
        ignore_patterns.match line.to_s
      rescue Exception
        nil
      end
  end
end

while (line = STDIN.gets)
  next if should_ignore_stderr(line,line_str)

  # ERR: lib/dmesg.rb:151:in `gsub!': invalid byte sequence in US-ASCII (ArgumentError)
  line2 = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
  line = line2.to_s.strip_nonprintable_characters
  id = common_error_id(line)
  next if id.size < 3

  # Don't treat the lines starting with
  # Date/Num/Hex Num/SHA as comments
  id.gsub(/^#/, "_#") if line[0] != "#"
  error_ids[id] = line
end

error_ids.each do |id_, line_|
  puts "# " + line_
  puts id_ + ": 1"
  puts
end

puts "has_stderr: 1" unless error_ids.empty?

log_warn "noisy stderr, check #{ENV["RESULT_ROOT"]}/stderr" if error_ids.size > 100
