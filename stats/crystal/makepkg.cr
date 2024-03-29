#!/usr/bin/env crystal

require "../../lib/string_ext"

stats_name = "fail: 1"

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?

  case line
  when /Makepkg finished successfully/
    stats_name = "pass: 1"
  end
end

puts stats_name
