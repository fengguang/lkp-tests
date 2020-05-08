#!/usr/bin/env crystal

time = 0
protocol = " "
lib_micro=Hash(String,String|Float64).new

STDIN.each_line do |line|
  case line
  when %r(bin/)
    protocol = line.split[10].to_s
  when /elasped/
    lib_micro[protocol] = line.split[3].to_s
    time += line.split[3].to_f
  end
end

lib_micro.each do |k, v|
  puts k + ": " + v.to_s
end

puts "total_elasped_time: " + time.to_s
