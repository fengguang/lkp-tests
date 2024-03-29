#!/usr/bin/env crystal

stats = Array(String).new
nr_test = 0

while (line = STDIN.gets)
  next if line =~ /fs_metadata|page_poisoning/

  case line
  when /^\s+(.+) --.* pass/
    stats << "#{$1}.pass: 1"
    nr_test += 1
  when /^\s+(.+) --.* failed/, /^\s+(.+) --.*no .* finished/
    stats << "#{$1}.fail: 1"
    nr_test += 1
  when /^\s+(.+) --.* skip/
    stats << "#{$1}.skip: 1"
    nr_test += 1
  when /(^[a-zA-Z].*?)\s+PASS\s+/
    stats << "#{$1.downcase}.pass: 1"
    nr_test += 1
  when /(^[a-zA-Z].*?)\s+FAIL\s+/
    stats << "#{$1.downcase}.fail: 1"
    nr_test += 1
  end
end

stats.each { |stat| puts stat }
puts "total_test: #{nr_test}"
