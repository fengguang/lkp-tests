#!/usr/bin/env crystal


require "../../lib/string_ext"

def show_dmesg_times
  dmesg = "#{ENV["RESULT_ROOT"]}/kmsg"
  return unless File.exists? dmesg

  dhcp = false
  smp_start = false

  File.open(dmesg).each_line do |line|
    line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
    case line
    when /\[ *(\d+\.\d+)\] Sending DHCP requests/
      unless dhcp
        puts "dhcp: " + $1
        dhcp = true
      end
    when /\[ *(\d+\.\d+)\] x86: Booting SMP configuration:/
      smp_start = $1.to_f
    when /\[ *(\d+\.\d+)\] smp: Brought up \d+ nodes, \d+ CPUs$/
      printf "smp_boot: %g\n", $1.to_f
    when /\[ *(\d+\.\d+)\] Freeing unused kernel memory:/
      puts "kernel_boot: " + $1
      break
    end
  end
end

show_dmesg_times

if (line = STDIN.gets)
  boot, idle = line.split
  puts "boot: " + boot
  puts "idle: " + idle
end
