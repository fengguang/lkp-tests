#!/usr/bin/env crystal

results = {}
leaking_number = 0

while (line = STDIN.gets)
  case line
  when /Total number of results.*: (.*)/
    total_number = $1
  when /^\[ +([\d\.]+)\](.*)/
    results["dmesg." + $2.sub!(/\b(0x)?ffff[[:xdigit:]]{12}\b/, "").delete(" ")] = 1
    leaking_number += 1
  when /^\[\d+ ([^\]]+)\](.*)/
    results["proc." + $1 + "." + $2.sub!(/\b(0x)?ffff[[:xdigit:]]{12}\b/, "").gsub(/\s+/, "")] = 1
    leaking_number += 1
  end
end

results["leaking_number"] = leaking_number
results["total_number"] = total_number

if results.empty?
  results["result.pass"] = 1
else
  results["result.fail"] = 1
end

results.each do |k, v|
  puts "#{k}: #{v}"
end
