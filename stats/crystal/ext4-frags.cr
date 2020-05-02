#!/usr/bin/env crystal

stats = []

while (line = STDIN.gets)
  case line
  when /^(ext4-frags).*(pass)/
    stats_type = $2
    stats << $1 + ".#{stats_type}: 1"
  end
end

stats.each { |stat| puts stat }
