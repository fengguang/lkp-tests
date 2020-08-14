#!/usr/bin/env ruby

stats = {}

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: '_') unless line.valid_encoding?
  case line
  when /\d*(not ok|ok).* - (.*)/
    result = $1.strip.tr(' ', '_')
    test = $2.strip.tr(' ', '_')
    stats[test] = result
  end
end

stats.each do |k, v|
  puts k + '.' + v + ': 1'
end
