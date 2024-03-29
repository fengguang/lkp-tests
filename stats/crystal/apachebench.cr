#!/usr/bin/env crystal

while (line = STDIN.gets)
  case line
  when /^Requests per second/, /^Transfer rate/, /^Time per request.*\(mean\)$/
    key, vals = line.split ": "
    val, _unit = vals.split " "
    key = key.downcase.tr(" ", "_")
    puts "#{key}: #{val}"
  when /^Connect:/, /^Processing:/, /^Waiting:/, /^Total:/
    key, vals = line.split ":"
    _min, _mean, _sd, _median, max = vals.split " "
    key = key.downcase
    puts "connection_time.#{key}.max: #{max}"
  when /^\s+\d+%/
    percent, val = line.split
    puts "max_latency.#{percent}: #{val}"
  end
end
