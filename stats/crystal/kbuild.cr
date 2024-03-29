#!/usr/bin/env crystal

# the workload of kbuild is defined as the iteration number
iterations = 0
runtime = 0
STDIN.each_line do |line|
  iterations = $1.to_i if line =~ /^iterations: (\d+)/
  runtime = $1.to_f if line =~ /^runtime: (\d+)/
end

if iterations != 0
  buildtime_per_iteration = runtime / iterations
  puts "buildtime_per_iteration: #{buildtime_per_iteration}"
  puts "workload: #{iterations}"
end
