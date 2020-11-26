#!/usr/bin/env crystal

#               prc thr   usecs/call      samples   errors cnt/samp
# close_tmp      1   1      0.61880          201        0      640

while (line = STDIN.gets)
  next unless line =~ /^(\w+)\s+\S+\s+\S+\s+(\S+)/

  puts "#{$1}: #{$2}"
end
