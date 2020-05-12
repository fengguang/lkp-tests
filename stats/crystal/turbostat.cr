#!/usr/bin/env crystal

while (line = STDIN.gets)
  next unless line =~ /Busy%/

  titles = line.split
  values = STDIN.gets.not_nil!.split("")
  titles[titles.size - values.size..-1].each_with_index do |title, i|
    next if values[i].includes? "*"
    next if values[i] == "-"

    puts title + ": " + values[i]
  end
  exit
end
