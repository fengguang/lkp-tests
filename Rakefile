require 'rubygems'
#require 'bundler/setup'
require 'rspec/core/rake_task'

ENV['LKP_SRC'] = File.expand_path "#{File.dirname(__FILE__)}"

#
# usage: rake spec spec=result_path
#
RSpec::Core::RakeTask.new do |t|
	spec = ENV['spec'] || '*'
	#
	# assume when run on inn, both lkp-core and lkp-tests are combined to single folder like src
	#
	if `hostname`.strip == 'inn'
		t.ruby_opts = "-I \"#{['lib', 'spec'].join(File::PATH_SEPARATOR)}\""
		t.pattern = "spec/**{,/*/**}/#{spec}_spec.rb"
	else
		t.ruby_opts = "-I \"#{['lib', 'spec', '../lkp-core/lib', '../lkp-core/spec'].join(File::PATH_SEPARATOR)}\""
		t.pattern = "{spec,../lkp-core/spec}/**{,/*/**}/#{spec}_spec.rb"
	end
end
