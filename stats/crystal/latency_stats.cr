#!/usr/bin/env crystal

# hits = Hash.new { |hash, key| hash[key] = 0 }
# sum = Hash.new { |hash, key| hash[key] = 0 }
# max = Hash.new { |hash, key| hash[key] = 0 }
# top = Hash.new { |hash, key| hash[key] = 0 }

hits = Hash(String, Int32).new(0)
sum = Hash(String, Int32).new(0)
max = Hash(String, Int32).new(0)
top = Hash(String, Int32 | Float64).new(0)

STDIN.each_line do |line|
  case line
  when /Latency Top version/
    next
  when /[0-9]+ [0-9]+ [0-9]+ [a-zA-Z]+/
    values = line.gsub(/\.(isra|constprop|part)\.[0-9]+/, "").split
    funcs = values[3..].join(".")
    hits[funcs] += values[0].to_i
    sum[funcs] += values[1].to_i
    max[funcs] = [values[2].to_i, max[funcs]].max
  end
end

def show_one(top, funcs, k, v)
  puts "#{k}.#{funcs}: #{v}"
  top[k] = v if top[k] < v
end

hits.each do |funcs, hit|
  show_one top, funcs, "hits", hit
  show_one top, funcs, "sum", sum[funcs]
  show_one top, funcs, "avg", sum[funcs] / hit
  show_one top, funcs, "max", max[funcs]
end

top.each do |k, v|
  puts "#{k}.max: #{v}"
end
