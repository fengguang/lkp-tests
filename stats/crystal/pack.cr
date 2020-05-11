#!/usr/bin/env crystal


require "../../lib/string_ext"

stats_name = "fail: 1"

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence() unless line.valid_encoding?

  case line
  when /^rsync error/
    break
  when /^total size is \S+  speedup is \S+$/
    stats_name = "pass: 1"
    break
  end
end

puts stats_name
