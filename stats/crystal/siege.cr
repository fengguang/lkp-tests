#!/usr/bin/env crystal


require "../../lib/statistics"

results = {}

while (line = STDIN.gets)
  case line
  when /^(.*):[\t\s]+([\d.]+)( (\S+))?/
    value = $2
    unit = "_" + $4 if $4
    unit ||= ""
    key = $1.tr(" ", "_") + unit
    results[key] ||= []
    results[key] << value.to_f
  end
end

results.each { |k, v| puts "#{k}: #{v.average}" }
