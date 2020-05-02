#!/usr/bin/env crystal

while (line = STDIN.gets)
  case line
  when /([\d.]+:) (.*): FAILED!$/
    case_name = $2.strip.tr(" ", "_")
    puts "#{case_name}.fail: 1"
  when /([\d.]+:) (.*): Ok$/
    case_name = $2.strip.tr(" ", "_")
    puts "#{case_name}.pass: 1"
  when /([\d.]+:) (.*): [Skip$|Skip .*]/
    case_name = $2.strip.tr(" ", "_")
    puts "#{case_name}.skip: 1"
  when /ignored_by_lkp: (.*)/
    case_name = $1.strip.tr(" ", "_")
    puts "#{case_name}.ignored_by_lkp: 1"
  end
end
