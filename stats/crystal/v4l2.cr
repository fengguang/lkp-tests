#!/usr/bin/env crystal

stats = {}

# skip invalid line
while (line = STDIN.gets)
  break if line =~ /Required ioctls/
end

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
  case line
  when /test (.*): (FAIL|OK)*/
    result = $2.downcase
    test = $1.downcase.gsub(" ", "_")
    stats[test] = result
  end
end

stats.each do |k, v|
  puts k + "." + v + ": 1"
end
