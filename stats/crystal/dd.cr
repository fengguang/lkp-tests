#!/usr/bin/env crystal

while (line = STDIN.gets)
  case line
  when /^startup_time_ms: /, /^kill_time_ms: /
    puts line
  end
end
