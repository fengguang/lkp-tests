#!/usr/bin/env crystal

RESULT_ROOT = ENV["RESULT_ROOT"]

require "json"

def calc_bootmem
  return unless File.exists?("#{RESULT_ROOT}/memmap.json")
  return unless File.exists?("#{RESULT_ROOT}/boot-meminfo.json")

  memmap = JSON.parse(File.read("#{RESULT_ROOT}/memmap.json"))
  meminfo = JSON.parse(File.read("#{RESULT_ROOT}/boot-meminfo.json"))

  printf "bootmem: %d\n", memmap["memmap.System_RAM"][0].as_i - meminfo["boot-meminfo.MemTotal"][0].as_i
end

calc_bootmem

exit unless File.exists?("#{RESULT_ROOT}/kmsg")

freed = 0

File.each_line("#{RESULT_ROOT}/kmsg") do |line|
  case line
  when /^(\[[0-9. ]+\] )?Memory: (\d+)k\/(\d+)k available \((\d+)k kernel code, (\d+)k reserved, (\d+)k data, (\d+)k init(, (\d+)k highmem)?/
    puts "free: " + $2
    puts "phys: " + $3
    puts "code: " + $4
    puts "reserved: " + $5
    puts "data: " + $6
    puts "init: " + $7
    puts "highmem: " + $9 if $8
  when /^(\[[0-9. ]+\] )?Memory: (\d+)k\/(\d+)k available \((\d+)k kernel code, (\d+)k absent, (\d+)k reserved, (\d+)k data, (\d+)k init/
    puts "free: " + $2
    puts "phys: " + $3
    puts "code: " + $4
    puts "absent: " + $5
    puts "reserved: " + $6
    puts "data: " + $7
    puts "init: " + $8
  when /^(\[[0-9. ]+\] )?Memory: (\d+)K\/(\d+)K available \((\d+)K kernel code, (\d+)K rwdata, (\d+)K rodata, (\d+)K init, (\d+)K bss, (\d+)K reserved(, (\d+)K highmem)?/
    puts "free: " + $2
    puts "phys: " + $3
    puts "code: " + $4
    puts "rwdata: " + $5
    puts "rodata: " + $6
    puts "init: " + $7
    puts "bss: " + $8
    puts "reserved: " + $9
    puts "highmem: " + $11 if $10
  when /^(\[[0-9. ]+\] )?Freeing .* memory: (\d+)K /
    freed += $2.to_i
  when /^(\[[0-9. ]+\] )?Freeing .*: (\d+)k freed$/
    freed += $2.to_i
  end
end

# MemTotal ==  free + freed
printf "freed: %d\n", freed
