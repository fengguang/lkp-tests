#!/usr/bin/crystal

UNIT = 1000.0
DEBUG = false
RESULT_ROOT = ENV["RESULT_ROOT"]


require "../../lib/noise"
require "../../lib/log"

time = {} of String => Array(Int32)
syscall_nr = {} of String => Int32

sys_nr = {} of String => Int32
sys_nr["total"] = 0
sys_nr["max"] = 0

def parse_process_lines(process_lines, time)
  syscall1 = syscall2 = ""
  syscall_start = syscall_end = 0
  start = true
  find_next = true
  last_line = "init"

  process_lines.each do |line|
    a = line.split("]")
    b = a[1].split

    if find_next
      if b[3] == "->"
        last_line = line
        next
      else
        find_next = false
        start = true
      end
    end

    if start
      if b[3] == "->"
        log_warn "not a START of syscall\n" + last_line + line if DEBUG
        find_next = true
        last_line = line
        next
      end
      c = b[2].split("(")
      syscall1 = c[0]
      syscall_start = b[1].to_i
      start = false
    else
      if b[3] != "->"
        log_warn "not a syscall return:\n" + last_line + line if DEBUG
        find_next = true
        last_line = line
        next
      end
      syscall2 = b[2]
      if syscall2 != syscall1
        log_warn "not the same syscall\n" + last_line + line if DEBUG
        find_next = true
        last_line = line
        next
      end
      syscall_end = b[1].to_i
      syscall_time = syscall_end - syscall_start
      time[syscall2] = [] of Int32 if time[syscall2].nil?
      time[syscall2] << syscall_time
      start = true
    end
    last_line = line
  end
end

def parse_syscalls(time)
  process_lines = {} of String=>Array(String)
  lines = if File.exists?("#{RESULT_ROOT}/ftrace.data.xz")
  	    File.read_lines("xzcat #{RESULT_ROOT}/ftrace.data.xz")
#            IO.popen("xzcat #{RESULT_ROOT}/ftrace.data.xz").readlines
#	    IO.readlines("xzcat #{RESULT_ROOT}/ftrace.data.xz")
          elsif File.exists?("#{RESULT_ROOT}/ftrace.data")
            File.read_lines("#{RESULT_ROOT}/ftrace.data")
          end

  if lines.nil?
    log_error "no ftrace.data or ftrace.data.xz in the #{RESULT_ROOT}"
    return
  end

  lines.each do |line|
    next if line.includes?("CPU") || line.includes?("#")

    a = line.split
    next if a[4].nil?

    process_name = a[0]
    process_lines[process_name] = [] of String if process_lines[process_name].nil?
    process_lines[process_name] << line
  end

  process_lines.each do |_process_name, line_array|
    parse_process_lines line_array, time
  end
end

def get_syscall_nr(time, syscall_nr, sys_nr)
  time.each do |syscall, time_array|
    syscall_nr[syscall] = time_array.size
  end

  syscall_nr.each do |_syscall, nr|
    sys_nr["total"] += nr
    sys_nr["max"] = nr if nr > sys_nr["max"]
  end
#  syscall_nr.to_a
  syscall_nr.to_a.sort_by { |_key, val| val }.reverse.to_h
end

def show_syscalls_noise(time, syscall_nr, sys_nr)
  a = get_syscall_nr time, syscall_nr, sys_nr
  i = 0
  a.each do |syscall, _nr|
    break if i == 5

    n = Noise.new syscall, time[syscall]
    n.analyse
    n.log
    i += 1
  end
end

parse_syscalls time
exit if time.nil?
show_syscalls_noise time, syscall_nr, sys_nr
