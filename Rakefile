require 'rubygems'
#require 'bundler/setup'
require 'rspec/core/rake_task'
require 'fileutils'

#
# usage: rake spec [spec=result_path]
# example:
# - "rake spec" : check all unit tests status
# - "rake spec spec=job" : check spec/job_spec.rb status
#

RSpec::Core::RakeTask.new do |t|
	ENV['LKP_SRC'] ||= File.expand_path "#{File.dirname(__FILE__)}"

	puts "PWD = #{Dir.pwd}"
	puts "ENV['LKP_SRC'] = #{ENV['LKP_SRC']}"

	spec = ENV['spec'] || '*'
	t.pattern = "spec/**{,/*/**}/#{spec}_spec.rb"
end

if ENV['GENERATE_REPORTS'] == 'true'
	require 'ci/reporter/rake/rspec'
	task :spec => 'ci:setup:rspec'
end

