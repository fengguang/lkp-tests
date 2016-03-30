require 'rspec'
require 'timeout'

$LOAD_PATH.concat($LOAD_PATH.shift(3))

require "#{ENV['LKP_SRC']}/lib/yaml"

describe WTMP do
	describe "load" do
		it "should handle control character" do
			result = described_class.load("time: 2015-08-06 20:25:44 +0800\nstate: running\n\ntime: 2015-08-06 20:29:21 +0800\nstate: finished\n\n\u0000\u0000\u0000\u0000")

			expect(result['state']).to eq 'finished'
		end
	end

	describe "load_tail" do
		it "should return nil if error" do
			result = described_class.load_tail("time: 2015-08-06 20:25:44 +0800state: running")
			expect(result).to be nil
		end
	end
end

describe "load_yaml_with_flock" do
	TEST_YAML_FILE = "/tmp/test.yaml".freeze

	before(:example) do
		File.open(TEST_YAML_FILE, 'w') { |f|
			f.write("key1: value1\nkey2: value2\n")
		}
	end

	it "should return correct value" do
		yaml = load_yaml_with_flock TEST_YAML_FILE
		expect(yaml['key2']).to eq 'value2'
	end

	it "should return nil due to flock by other process" do
		f = File.open(TEST_YAML_FILE + '.lock', File::RDWR|File::CREAT, 0664)
		f.flock(File::LOCK_EX)

		yaml = Timeout::timeout(0.001) { load_yaml_with_flock TEST_YAML_FILE } rescue nil
		f.close
		expect(yaml).to be nil
	end

	after(:example) do
		FileUtils.rm TEST_YAML_FILE
		FileUtils.rm TEST_YAML_FILE + '.lock'
	end
end

describe "save_yaml_with_flock" do
	TEST_YAML_OBJ = {"key1"=>"value1","key2"=>"value2"}

	it "should save yaml file correctly" do
		save_yaml_with_flock TEST_YAML_OBJ, TEST_YAML_FILE
		yaml = load_yaml TEST_YAML_FILE
		expect(yaml['key2']).to eq 'value2'
	end

	it "should return false due to flock by other process" do
		f = File.open(TEST_YAML_FILE + '.lock', File::RDWR|File::CREAT, 0664)
		f.flock(File::LOCK_EX)

		Timeout::timeout(0.001) { save_yaml_with_flock TEST_YAML_OBJ, TEST_YAML_FILE } rescue nil
		f.close
		expect(File.exist? TEST_YAML_FILE).to be false
	end

	after(:example) do
		FileUtils.rm_rf TEST_YAML_FILE
		FileUtils.rm_rf TEST_YAML_FILE + '.lock'
	end
end

