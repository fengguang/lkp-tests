#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath(PROGRAM_NAME)))

require "yaml"
require "../../lib/log"

RESULT_ROOT = ENV["RESULT_ROOT"]

exit unless File.exist?("#{RESULT_ROOT}/results/default/status.json")
status = YAML.load_file("#{RESULT_ROOT}/results/default/status.json")

if status["operations"].nil? || status["operations"].empty?
  log_error "Test environment is not enabled"
  exit
end

status["operations"].each do |op|
  if op["status_code"] == "GOOD"
    puts "#{op["subdir"]}.pass: 1"
  else
    puts "#{op["subdir"]}.fail: 1"
  end
end

exit unless File.exist?("#{RESULT_ROOT}/results/default/compilebench/results/keyval")
File.open("#{RESULT_ROOT}/results/default/compilebench/results/keyval", "r") do |f|
  f.each_line do |line|
    puts "compilebench." + line.gsub(/{perf}=/, ": ")
  end
end
