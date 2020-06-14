require "yaml"

RESULT_ROOT = ENV["RESULT_ROOT"]

job = File.open(RESULT_ROOT + "/job.yaml") do |file|
  YAML.parse(file)
end
exit unless job

kernel_size_file = "#{File.dirname job["kernel"].to_s}/kernel_size"
exit unless File.exists? kernel_size_file

text, data, bss = `tail -n 1 #{kernel_size_file}`.split

puts "text: #{text}"
puts "data: #{data}"
puts "bss: #{bss}"
