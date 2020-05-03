#!/usr/bin/env crystal


require "../../lib/log"
require "../../lib/string_ext"

# skip none-result data
while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
  break if line =~ /\(secs\)    \(secs\)    \(secs\)/
end

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
  # cut the left we don't care
  break if line =~ /run time:/

  res_line = line.split
  if res_line.size != 10
    log_error "WARNING: unexpected stress-ng output: #{line}"
    next
  end
  puts res_line[3] + ".ops: " + res_line[4]
  puts res_line[3] + ".ops_per_sec: " + res_line[8]
end
