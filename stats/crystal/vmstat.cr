#!/usr/bin/env crystal

require "time"

# procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu----- -----timestamp-----
#  r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st                 PST
#  2  0      0 224636  33636 6760228    0    0    54   141  129   23  1  1 98  0  0 2015-01-11 20:18:35
#  0  0      0 224752  33636 6760180    0    0     0     4  753 2187  2  1 98  0  0 2015-01-11 20:18:36

keys = %w(procs.r procs.b memory.swpd memory.free
  memory.buff memory.cache swap.si swap.so io.bi
  io.bo system.in system.cs cpu.us cpu.sy cpu.id cpu.wa cpu.st time)

old_keys = %w(time procs.r procs.b memory.swpd memory.free
  memory.buff memory.cache swap.si swap.so io.bi
  io.bo system.in system.cs cpu.us cpu.sy cpu.id cpu.wa cpu.st)

# To match output from vmstat 3.3.8
keys_v338 = %w(procs.r procs.b memory.swpd memory.free
  memory.buff memory.cache swap.si swap.so io.bi
  io.bo system.in system.cs cpu.us cpu.sy cpu.id cpu.wa)

def show_record(keys, data)
  data.each_with_index { |v, i| puts "#{keys[i]}: #{v}" }
end

while (line = STDIN.gets)
  next unless line =~ /[0-9]/

  data = line.split
  if data.size == keys.size + 1 # has "date time" in end of line
    # time = Time.parse(data.pop(2).join(" "), "%y-%M-%d %H:%m:%s", Time::Location.load("China/Beijing")).to_s.to_i
    time = Time.parse_local(data.pop(2).join(" "), "%F %T").to_unix
    data.push time.to_s
    show_record keys, data
  elsif data.size == keys.size - 1 # no timestamp in old versions of vmstat
    show_record keys, data
  elsif data.size == old_keys.size # has timestamp in the first column
    show_record old_keys, data
  elsif data.size == keys_v338.size # vmstat version 3.3.8
    show_record keys_v338, data
  end
end
