#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require "#{LKP_SRC}/lib/string_ext"

def largest_bandwidth
  file_size = 0
  bandwidth = 0

  $stdin.each_line do |line|
    break if line.empty?

    temp_size = line.split(" ")[0].to_f
    temp_bandwidth = line.split(" ")[1].to_f
    if temp_size > file_size
      file_size = temp_size
      bandwidth = temp_bandwidth
    end
  end
  bandwidth
end

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
  case line
  # Extract syscall test result.
  # Simple syscall: 0.2228 microseconds
  # Simple read: 0.3491 microseconds
  # Simple write: 0.2933 microseconds
  # Simple stat: 0.7039 microseconds
  # Simple fstat: 0.3517 microseconds
  # Simple open/close: 1.3696 microseconds
  when /^Simple (\S+): (\d+.\d+) microseconds$/
    puts "syscall.#{$1}.latency.us: #{$2}"

    # Extract select test result.
    # Select on 100 fd's: 1.2293 microseconds
    # Select on 100 tcp fd's: 5.0377 microseconds
  when /^Select on 100 fd\'s: (\d+.\d+) microseconds$/
    puts "Select.100fd.latency.us: #{$1}"
  when /^Select on 100 tcp fd\'s: (\d+.\d+) microseconds$/
    puts "Select.100tcp.latency.us: #{$1}"

    # Extract proc test result.
    # Process fork+exit: 134.4530 microseconds
    # Process fork+execve: 382.2759 microseconds
    # Process fork+/bin/sh -c: 918.9524 microseconds
  when /^Process (fork\+\S+)(?:\s-c)?: (\d+.?\d+) microseconds$/
    puts "Process.#{$1}.latency.us: #{$2}"

    # Extract pipe test result.
    # Pipe latency: 7.9239 microseconds
    # Pipe bandwidth: 3042.74 MB/sec
  when /^Pipe latency: (\d+.\d+) \S+$/
    puts "PIPE.latency.us: #{$1}"
  when /^Pipe bandwidth: (\d+.\d+) \S+$/
    puts "PIPE.bandwidth.MB/sec: #{$1}"

    # Extract unix test result.
    # AF_UNIX sock stream latency: 6.2302 microseconds
    # AF_UNIX sock stream bandwidth: 7058.07 MB/sec

  when /^AF_UNIX sock stream latency: (\d+.\d+) \S+$/
    puts "AF_UNIX.sock.stream.latency.us: #{$1}"
  when /^AF_UNIX sock stream bandwidth: (\d+.\d+) \S+$/
    puts "AF_UNIX.sock.stream.bandwidth.MB/sec: #{$1}"

    # Extract ops test results.
    # integer bit: 0.33 nanoseconds
    # integer add: 0.09 nanoseconds
    # integer mul: 0.01 nanoseconds
    # integer div: 7.70 nanoseconds
    # integer mod: 8.12 nanoseconds
    # int64 bit: 0.31 nanoseconds
    # int64 add: 0.08 nanoseconds
    # int64 mul: -0.02 nanoseconds
  when /^(integer|int64|float|double) (bit|add|mul|div|mil): (\d+.\d+) nanoseconds$/
    puts "OPS.#{$1}.#{$2}.latency.ns: #{$3}"

    # Extract UDP test result:
    # UDP latency using localhost: 8.4815 microseconds
  when /^UDP latency using localhost: (\d+.\d+) microseconds$/
    puts "UDP.usinglocalhost.latency.us: #{$1}"

    # For CTX test reuslt, only extract part of data, context switching times for
    # 96p/0K, 96p/16K, 96p/64K (processes/process_size).
    # "size=0k ovr=0.90
    # 2 1.45
    # 4 1.51
    # 8 1.65
    # 16 1.77
  when /^"size=\d+k ovr=\d+.\d+$/
    size = line.split[0].split("=")[-1].to_i
  when ([0, 16, 64].includes? size) && /^96 (\d+.\d+)$/
    puts "CTX.96P.#{size}K.latency.us: #{$1}"

    # Extract FILE test result, get the bandwidth value for the biggest file reading:
    # "read bandwidth
    # 0.000512 489.40
    # 0.001024 900.99
    # 0.002048 1757.11

  when /^"read bandwidth$/
    read_bandwidth = true
    file_size = 0
  when read_bandwidth && /^(\d+.\d+) (\d+.\d+)$/
    if file_size < $1.to_f
      file_size = $1.to_f
      bandwidth = $2
    end
  when read_bandwidth && bandwidth && /^[^\d+]/
    puts "FILE.read.bandwidth.MB/sec: #{bandwidth}"
    read_bandwidth = false

    # Extract TCP test result, get TCP bandwidth value for 64B,10M of message size:
    # TCP latency using localhost: 14.4782 microseconds
    # Socket bandwidth using localhost
    # 0.000001 1.82 MB/sec
    # 0.000064 108.22 MB/sec
    # 0.000128 210.87 MB/sec

  when /^TCP latency using localhost:.+microseconds$/
    puts "TCP.localhost.latency: #{line.split[-2]}"
  when /^Socket bandwidth using localhost$/
    socket_bandwidth = true
  when socket_bandwidth && /^0.000064 (\d+.\d+) MB\/sec$/
    puts "TCP.socket.bandwidth.64B.MB/sec: #{$1}"
  when socket_bandwidth && /^10.485760 (\d+.\d+) MB\/sec$/
    puts "TCP.socket.bandwidth.10MB.MB/sec: #{$1}"

    # Extract CONNECT test result:
    # TCP/IP connection cost to localhost: 19.1327 microseconds
  when /^TCP\/IP connection cost to localhost: (\d+.\d+) microseconds/
    puts "CONNECT.localhost.latency.us: #{$1}"

    # Extract BCOPY test result:
    # bcopy test outputs some test results,but only get the last largest result from the last line.
    # According to lmbench3 source script "getsummary" to extract the four items test result:
    # libc bcopy unaligned, unrolled bcopy unaligned, Memory read bandwidth, Memory write bandwidth.

    # "libc bcopy unaligned"
    # 0.000512 39318.87
    # 0.001024 43561.22
    # 0.002048 48679.99
    # 0.004096 49481.95
    # 0.008192 52732.95
    # ...
  when /^"libc bcopy unaligned$/
    puts "BCOPY.libc.bandwidth.MB/sec: #{largest_bandwidth}"

    # "unrolled bcopy unaligned
    # 0.000512 13442.67
    # 0.001024 13699.91
    # 0.002048 13853.59
    # 0.004096 13955.43
    # 0.008192 13872.00
    # 0.016384 12921.17
    # ...
  when /^"unrolled bcopy unaligned$/
    puts "BCOPY.unrolled.bandwidth.MB/sec: #{largest_bandwidth}"

    # Memory read bandwidth
    # 0.000512 16353.73
    # 0.001024 16577.89
    # 0.002048 16752.28
    # 0.004096 16822.85
    # 0.008192 16834.82
    # ...
  when /^Memory read bandwidth$/
    puts "BCOPY.memory_read.bandwidth.MB/sec: #{largest_bandwidth}"

    # Memory write bandwidth
    # 0.000512 13964.88
    # 0.001024 13954.19
    # 0.002048 13975.07
    # 0.004096 13950.82
    # ...
  when /^Memory write bandwidth$/
    puts "BCOPY.memory_write.bandwidth.MB/sec: #{largest_bandwidth}"

    # Pagefaults on /var/tmp/XXX: 0.2653 microseconds
  when /^Pagefaults on (.*): (.*) microseconds/
    puts "Pagefaults.ms: #{$2}"

    # "Mmap read bandwidth
    # 0.000512 275064.12
    # 0.001024 280518.89
    # 0.002048 293513.60
    # ...
  when /^"Mmap read bandwidth$/
    puts "MMAP.read.bandwidth.MB/sec: #{largest_bandwidth}"

    # "Mmap read open2close bandwidth
    # 0.000512 479.98
    # 0.001024 964.48
    # 0.002048 1931.69
    # ...
  when /^"Mmap read open2close bandwidth$/
    puts "MMAP.read_open2close.bandwidth.MB/sec: #{largest_bandwidth}"
  end
end
