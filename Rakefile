require 'rubygems'
#require 'bundler/setup'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new do |t|
	# handle execution in either server or local
	t.ruby_opts = "-I \"#{['lib', 'spec', '../lkp-core/lib', '../lkp-core/spec'].join(File::PATH_SEPARATOR)}\""
	t.pattern = '{spec,../lkp-core/spec}/**{,/*/**}/*_spec.rb'
end
