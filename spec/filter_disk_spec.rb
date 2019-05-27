require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require "#{LKP_SRC}/lib/job"

describe 'filter/disk', :lkp do
  before(:all) do
    @tmp_dir = Dir.mktmpdir(nil, '/tmp')
    FileUtils.chmod 'go+rwx', @tmp_dir

    @test_yaml_file = "#{@tmp_dir}/test.yaml".freeze
  end

  after(:all) do
    FileUtils.remove_entry @tmp_dir
  end

  context 'when do not need disk' do
    it 'does not filter the job' do
      File.open(@test_yaml_file, 'w') do |f|
        f.write({ 'testcase' => 'testcase' }.to_yaml)
      end
      job = Job.open(@test_yaml_file)
      job.expand_params
    end
  end

  context 'when disk: 1HDD, nr_hdd_partitions: 1' do
    it 'does not filter the job' do
      File.open(@test_yaml_file, 'w') do |f|
        f.write({ 'testcase' => 'testcase', 'nr_hdd_partitions' => '1', 'disk' => '1HDD' }.to_yaml)
      end
      job = Job.open(@test_yaml_file)
      job.expand_params
    end
  end

  context 'when disk: 4HDD, nr_hdd_partitions: 1' do
    it 'filter the job' do
      File.open(@test_yaml_file, 'w') do |f|
        f.write({ 'testcase' => 'testcase', 'nr_hdd_partitions' => '1', 'disk' => '4HDD' }.to_yaml)
      end
      job = Job.open(@test_yaml_file)
      expect { job.expand_params }.to raise_error Job::ParamError
    end
  end

  context 'when disk: 1HDD, do not have hdd_partition' do
    it 'filter the job' do
      File.open(@test_yaml_file, 'w') do |f|
        f.write({ 'testcase' => 'testcase', 'disk' => '1HDD' }.to_yaml)
      end
      job = Job.open(@test_yaml_file)
      expect { job.expand_params }.to raise_error Job::ParamError
    end
  end
end
