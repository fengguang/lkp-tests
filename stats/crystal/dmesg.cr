#!/usr/bin/env crystal

# dmesg and kmsg both their strengths and limitations, so both are used.
#
# dmesg - data from serial console
# kmsg  - data from /dev/kmsg inside the running kernel
#
# dmesg is only available for the KVM test boxes and the test boxes that
# have serial console output. Near half of the physical test boxes do
# not have serial console, hence do not have these dmesg files -- they
# only have RESULT_ROOT/kmsg which is the output of /proc/kmsg and
# collected inside the running kernel. dmesg is collected outside of the
# running kernel, so is more reliable when there are kernel oops. While
# kmsg is more accurate than the lossy/noisy serial console when there
# is no oops.
#
# So we use dmesg.* stats (which try to use dmesg then fall back to kmsg)
# to catch obvious kernel warning/bugs, while use kmsg.* stats (which is based
# on kmsg and falls back to dmesg) to catch 50000+ printk messages whose level
# is >= KERN_WARNING.

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath(PROGRAM_NAME)))

require "../../lib/dmesg"
require "../../lib/log"
require "../../lib/string_ext"

if ARGV[0]
  kmsg_file = ARGV[0]
  dmesg_file = ARGV[0]
  RESULT_ROOT = ENV["RESULT_ROOT"]
elsif ENV["RESULT_ROOT"]
  RESULT_ROOT = ENV["RESULT_ROOT"]
  serial_file = "#{RESULT_ROOT}/dmesg"
  kmsg_file = "#{RESULT_ROOT}/kmsg"
  if File.exist? serial_file
    dmesg_file = serial_file

    if File.size?(kmsg_file) && File.size(serial_file).zero?
      log_error "unexpected 0-sized serial file #{serial_file}"
      dmesg_file = kmsg_file
    else
      kmsg_file = dmesg_file
    end
  elsif File.exist? kmsg_file
    dmesg_file = kmsg_file
  else
    # disabled due to not applicable for "lkp run";
    # "last_state.booting" should be enough
    #
    # puts "early-boot-hang: 1"
    exit
  end
else
  exit
end

unless File.size? dmesg_file
  # puts "early-boot-hang: 1"
  exit
end

dmesg_lines = fixup_dmesg_file(dmesg_file)

# check possibly misplaced serial log
def verify_serial_log(dmesg_lines)
  return unless PROGRAM_NAME =~ /dmesg/
  return if RESULT_ROOT.nil? || RESULT_ROOT.empty?

  dmesg_lines.grep(/RESULT_ROOT=/) do |line|
    next if line =~ /(^|[0-9]\] )kexec -l | --initrd=| --append=|"$/
    next unless line =~ / RESULT_ROOT=([A-Za-z0-9.,;_\/+%:@=-]+) /

    rt = $1
    next unless Dir.exist? rt # serial console is often not reliable

    log_error "RESULT_ROOT mismatch in dmesg: #{RESULT_ROOT} #{rt}" if rt != RESULT_ROOT
  end
end

verify_serial_log(dmesg_lines)

error_ids = {}
error_lines = {}
error_stamps = {}

if PROGRAM_NAME =~ /dmesg/
  lines = dmesg_lines
  oops_map = grep_crash_head dmesg_file
else
  if kmsg_file == dmesg_file
    kmsg_lines = dmesg_lines
    kmsg = kmsg_lines.join "\n"
  elsif File.exist?(kmsg_file)
    kmsg = File.read kmsg_file
    kmsg_lines = kmsg.split("\n")
  end

  lines = kmsg_lines
  output = grep_printk_errors kmsg_file, kmsg
  output.replace_invalid_utf8!

  oops_map = {}
  output.each_line do |line|
    oops_map[line] ||= line
  end
end

lines.reverse_each do |line|
  if line =~ /^(<[0-9]+>|....  :..... : )?\[ *(\d{1,6}\.\d{6})\] /
    error_stamps["last"] = $2
    break
  end
end

def stat_unittest(unittests)
  found_unitest = false
  unittests.each do |line|
    if line =~ /### dt-test ### start of unittest/
      found_unitest = true
      next
    end
    next unless found_unitest
    break if line =~ /### dt-test ### end of unittest - (\d+) passed, (\d+) failed/
    # ### dt-test ### FAIL of_unittest_overlay_high_level():2475 overlay_base_root not initialized
    if line =~ /(.*)### dt-test ### FAIL (.*)/
      e = $2.gsub(/:|\d+/, "").gsub(" ", "_")
      puts "unittest.#{e}.fail: 1"
    end
  end
end

stat_unittest(lines) if PROGRAM_NAME =~ /kmsg/

oops_map.each do |bug_to_bisect, line|

  timestamp = $2 if line =~ /^(<[0-9]+>|....  :..... : )?\[ *(\d{1,6}\.\d{6})\] /

  if line.index("trinity")
    break if line.index("invoked oom-killer:")
    break if line.index("page allocation stalls for")
    break if line.index("tried to map")
  end

  # print_hex_dump
  # kern  :alert : [  205.863334] rcu-torture: Free-Block Circulation:  3811 3811 3810 3809 3808 3807 3806 3805 3804 3803 0
  next if line =~ /(\s[0-9a-f]{2}){16}/
  next if line =~ /\[ *(\d{1,6}\.\d{6})\]\s*(\s[0-9a-f]{4}){8}$/
  next if line =~ /\[ *(\d{1,6}\.\d{6})\]\s*(\s[0-9a-f]{8}){4}$/

  next if line =~ /[^\t\n\0[:print:]]/

  line.tr! "\0", ""

  error_id, bug_to_bisect = analyze_error_id bug_to_bisect
  next if error_id.size <= 3
  next if bug_to_bisect.empty?

  error_ids[error_id] ||= bug_to_bisect
  error_lines[error_id] ||= line
  error_stamps[error_id] ||= timestamp if timestamp
end

puts "boot_failures: 1" if PROGRAM_NAME =~ /dmesg/ && !error_ids.empty?

# This shows each error id only once
error_ids.each do |error_id, line|
  puts
  puts "# " + line
  puts error_id + ": 1"
  puts "message:" + error_id + ": " + error_lines[error_id]
  puts "pattern:" + error_id + ": " + line
end

puts
error_stamps.each do |error_id, timestamp|
  puts "timestamp:#{error_id}: #{timestamp}"
end
