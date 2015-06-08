require 'rubygems'
#require 'bundler/setup'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new do |t|
	t.ruby_opts = "-I \"#{['lib', 'spec'].join(File::PATH_SEPARATOR)}\""
end
