#!/usr/bin/env crystal

stats = []

while (line = STDIN.gets)
  case line
  when /^(test-.*): (PASS|SKIP|FAIL)/
    stats << "#{$1}.#{$2.downcase}: 1"
  end
end

stats.each { |stat| puts stat }
