#!/usr/bin/env crystal

MAX_STACK_DEPTH = 5
THRESHOLD = 0.01

def parse
  results = {} of String=>Hash(Float64,Float64)
  cmd = "0"
  funcs = [] of String

  add_result = ->{
    unless funcs.empty?
      funcs = funcs.first(MAX_STACK_DEPTH)
      results[cmd] ||= Hash(Float64,Float64).new(0)
      results[cmd][funcs.join(".").to_f] += 1_f64
      funcs = [] of String
    end
  }
    STDIN.each_line do |line|
      if line.starts_with?("/proc/")
        add_result.call
        cmd = line.split[1].split("/")[0]
      elsif line =~ /\[<[0-9a-f]+>\] ([a-zA-Z_][a-zA-Z0-9_]+)/
        funcs.push $1
      end
    end
    add_result.call

  results.each do |c, cmd_result|
    nr = cmd_result.reduce(0) { |acc, elem| acc + elem[1] }
    results[c] = cmd_result.map { |bt, val| [bt, val * 100.0 / nr] }.to_h
  end
  results
end

def display(results)
  results.each do |cmd, cmd_result|
    cmd_result.to_a.sort_by! { |r| r[1] }
    cmd_result.to_a.reverse_each do |bt, p|
      break if p < THRESHOLD

      puts "#{cmd}.#{bt}: #{p}"
    end
  end
end

display parse
