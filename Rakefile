require 'rubygems'
#require 'bundler/setup'
require 'rspec/core/rake_task'
require 'fileutils'

#
# usage: rake spec spec=result_path
#

RSpec::Core::RakeTask.new do |t|
	ENV['LKP_SRC'] ||= File.expand_path "#{File.dirname(__FILE__)}"

	puts "PWD = #{Dir.pwd}"
	puts "ENV['LKP_SRC'] = #{ENV['LKP_SRC']}"

	spec = ENV['spec'] || '*'
	t.pattern = "spec/**{,/*/**}/#{spec}_spec.rb"
end
