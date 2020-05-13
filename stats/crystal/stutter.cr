#!/usr/bin/env crystal

stats = [] of String

while (line = STDIN.gets)
  case line
  when /^(stutter).*(fail|pass)/
    stats_type = $2
    stats << $1 + ".#{stats_type}: 1"
  end
end

stats.each { |stat| puts stat }
