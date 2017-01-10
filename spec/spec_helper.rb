require 'rspec'

if ENV['GENERATE_COVERAGE'] == 'true'
	require 'simplecov'
	require 'simplecov-rcov'
	SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
	SimpleCov.start
end

$LOAD_PATH.delete_if { |p| File.expand_path(p) == File.expand_path('./lib') }

LKP_SRC ||= ENV['LKP_SRC']
