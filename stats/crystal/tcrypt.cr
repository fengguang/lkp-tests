#!/usr/bin/env crystal


##require "fileutils"
require "../../lib/statistics"

RESULT_ROOT = ENV["RESULT_ROOT"]

results_test = {"test" => ""}
results_val = {"val" => [] of Int32 | Float64}

exit unless File.exists?("#{RESULT_ROOT}/kmsg")

def show_one(new_test, results_test,results_val)

  printf "%s: %d\n", results_test["test"], results_val["val"].average unless results_test["test"].empty? || results_val["val"].empty?
  results_test["test"] = new_test
  results_val["val"] = [] of Int32|Float64
end

File.each_line("#{RESULT_ROOT}/kmsg") do |line|  
  case line
  when /testing speed of (.*)$/
        show_one($1.tr(" ", "."), results_test,results_val)
  when /\d+ operations in (\d+) seconds \((\d+) bytes\)/
        bps = $2.to_i / $1.to_i
        results_val["val"] << bps
  when /\d+ opers\/sec, +(\d+) bytes\/sec/
        bps = $1.to_i
	results_val["val"] << bps
  end
end

show_one("", results_test,results_val)
