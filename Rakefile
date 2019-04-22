require 'rubygems'
require 'bundler/setup'
require 'rspec/core/rake_task'
require 'fileutils'
require 'rubocop/rake_task'

# SPEC
#
# usage: rake spec [spec=result_path]
# example:
# - "rake spec" : check all unit tests status
# - "rake spec spec=job" : check spec/job_spec.rb status
#
# RUBOCOP
#
# usage: rake rubocop [file=pattern]
# example:
#   - rake rubocop file="lib/**/*.rb": check all lib files

RSpec::Core::RakeTask.new do |t|
  ENV['LKP_SRC'] ||= File.expand_path File.dirname(__FILE__).to_s

  puts "PWD = #{Dir.pwd}"
  puts "ENV['LKP_SRC'] = #{ENV['LKP_SRC']}"

  spec = ENV['spec'] || '*'
  t.pattern = "spec/**{,/*/**}/#{spec}_spec.rb"
end

if ENV['GENERATE_REPORTS'] == 'true'
  require 'ci/reporter/rake/rspec'
  task spec: 'ci:setup:rspec'
end

begin
  RuboCop::RakeTask.new(:rubocop) do |t|
    t.options = ['-D', '-c.rubocop.yml']
    t.patterns = [ENV['file']] if ENV['file']

    puts "PWD = #{Dir.pwd}"
    puts "rubocop.patterns = #{t.patterns}"
    puts "rubocop.options = #{t.options}"
  end
rescue StandardError => e
  puts e.to_s
end
