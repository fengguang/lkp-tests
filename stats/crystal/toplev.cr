#!/usr/bin/env crystal
require "csv"

# Examples of toplev.csv output.
# # 3.5-full on Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
# 1.000792821,S0-C0,Frontend_Bound,38.98,% Slots,,,0.00,14.29,
# 1.000792821,S0-C0,Backend_Bound,41.09,% Slots,,,0.00,14.29,<==
# 1.000792821,S0-C0-T0,MUX,14.29,%,,,0.00,100.0,
# 1.000792821,S0-C1,Frontend_Bound,55.75,% Slots,,,0.00,14.29,<==
# 1.000792821,S0-C1,Backend_Bound,28.27,% Slots,,,0.00,14.29,
# 1.000792821,S0-C1-T0,MUX,14.29,%,,,0.00,100.0,
# 1.000792821,S0-C12,Frontend_Bound,42.58,% Slots,,,0.00,14.29,<==
# 1.000792821,S0-C12,Backend_Bound,39.89,% Slots,,,0.00,14.29,
# 1.000792821,S0-C12-T0,MUX,14.29,%,,,0.00,100.0,
# 1.000792821,S0-C13,Frontend_Bound,29.64,% Slots,,,0.00,11.59,
# 1.000792821,S0-C13,Bad_Speculation,37.70,% Slots,,,0.00,11.59,<==
# 1.000792821,S0-C13-T0,MUX,11.59,%,,,0.00,100.0,

# # 3.5-full on Intel(R) Core(TM) i5-3550 CPU @ 3.30GHz
# 1.000108004,Backend_Bound,100.00,% Slots,,,0.00,100.0,<==
# 2.000233423,Backend_Bound,100.00,% Slots,,,0.00,100.0,<==

RESULT_ROOT = ENV["RESULT_ROOT"]
exit unless File.exists?("#{RESULT_ROOT}/toplev.csv")
toplev_csv = "#{RESULT_ROOT}/toplev.csv"

last_time = ""
bottleneck_value = 0
CSV.foreach(toplev_csv) do |row|
  next if row[0] =~ /^#/

  # row = ["8.048139281", "S0-C0", "Frontend_Bound",
  #        "69.86", "% Slots", nil, nil, "0.00", "0.0", "<=="]
  time = row.shift
  puts "time: #{time}" if time != last_time
  last_time = time
  key_arr = []
  row.each do |item|
    case item
    when /\d+\.\d+/
      bottleneck_value = item
      break
    else
      key_arr.push item
    end
  end
  key = key_arr.join(".")
  puts "#{key}: #{bottleneck_value}"
end
