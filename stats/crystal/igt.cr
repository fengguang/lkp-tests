#!/usr/bin/env crystal

stats = []

while (line = STDIN.gets)
  case line
  when /^(.*): (SUCCESS|FAIL)/
    if $2 == "SUCCESS"
      stats_type = "pass"
    else
      stats_type = "fail"
    end
    stats << $1.tr(" /", "_.") + ".#{stats_type}: 1"
  end
end

stats.uniq.each { |stat| puts stat }
