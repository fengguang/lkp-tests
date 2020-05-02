#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require "#{LKP_SRC}/lib/statistics"
require "#{LKP_SRC}/lib/log"

keys = %w(gbyte nr_tests cachelines user_time sys_time elapsed_time
          faults_per_sec_per_cpu faults_per_sec)

while (line = STDIN.gets)
  case line
  when /^Clients: (\d+)$/
    clients = $1
  when /^Iteration: \d+$/
    line = STDIN.gets
    unless line
      log_error "empty line"
      exit
    end

    line = STDIN.gets
    unless line
      log_error "empty line"
      exit
    end

    data = line.split
    if data.size != keys.size
      log_error "data.size #{data.size} != keys.size #{keys.size}"
      exit
    end

    data.each_with_index do |v, i|
      puts "# " + clients + "." + keys[i] + ": " + v.chomp("s")
    end
    puts keys[-2] + ": " + data[-2]
  end
end
