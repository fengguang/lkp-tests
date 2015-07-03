require 'rubygems'
#require 'bundler/setup'
require 'rspec/core/rake_task'
require 'fileutils'

#
# when run locally, execute rake command under lkp-tests
# when run on inn
#   - update lkp-core/tests to inn ~ folder from dbox
#   - ssh inn
#   - execute rake command under ~/lkp-tests
#
# usage: rake spec spec=result_path
#        rake lkp_spec spec=result_path
#

RSpec::Core::RakeTask.new do |t|
	ENV['LKP_SRC'] ||= File.expand_path "#{File.dirname(__FILE__)}"
	puts "PWD=#{Dir.pwd}, ENV['LKP_SRC']=#{ENV['LKP_SRC']}"

	spec = ENV['spec'] || '*'

	t.ruby_opts = "-I \"#{['lib', 'spec'].join(File::PATH_SEPARATOR)}\""
	t.pattern = "spec/**{,/*/**}/#{spec}_spec.rb"
end

desc "Combine lkp-core/lkp-tests to src and run spec in src"
task :lkp_spec do |t|
	git_dir = File.expand_path "#{File.dirname(__FILE__)}/.."
	lkp_src_dir = File.join(git_dir, 'src')

	FileUtils.cd(git_dir) do
		FileUtils.rm_r lkp_src_dir, force: true

		FileUtils.mkdir_p lkp_src_dir
		FileUtils.cp_r Dir.glob("#{git_dir}/{lkp-tests,lkp-core}/*/"), lkp_src_dir
	end

	Dir.chdir(lkp_src_dir) do
		ENV['LKP_SRC'] = Dir.pwd
		Rake::Task[:spec].invoke
	end
end
