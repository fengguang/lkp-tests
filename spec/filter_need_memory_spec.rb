require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require "#{LKP_SRC}/lib/job"
require "#{LKP_SRC}/lib/bash"

system_free_mem_gb = Integer(Bash.call("free -g | sed -n '2, 1p' | awk '{print $7}'"))

describe 'filters/need_memory' do
  before(:all) do
    @tmp_dir = Dir.mktmpdir(nil, '/tmp')
    FileUtils.chmod 'go+rwx', @tmp_dir

    @test_yaml_file = "#{@tmp_dir}/test.yaml".freeze
  end

  after(:all) do
    FileUtils.remove_entry @tmp_dir
  end

  context 'when do not have need_memory' do
    it 'does not filter the job' do
      File.open(@test_yaml_file, 'w') do |f|
        f.write({ 'testcase' => 'testcase' }.to_yaml)
      end
      job = Job.open(@test_yaml_file)
      job.expand_params
    end
  end

  context 'when need_memory smaller than available_memory' do
    it 'does not filter the job' do
      File.open(@test_yaml_file, 'w') do |f|
        f.write({ 'testcase' => 'testcase', 'need_memory' => "#{system_free_mem_gb - 1}G" }.to_yaml)
      end
      job = Job.open(@test_yaml_file)
      job.expand_params
    end
  end

  context 'when need_memory larger than available_memory' do
    it 'filter the job' do
      File.open(@test_yaml_file, 'w') do |f|
        f.write({ 'testcase' => 'testcase', 'need_memory' => '100%', 'nr_cpu' => system_free_mem_gb + 2 }.to_yaml)
      end
      job = Job.open(@test_yaml_file)
      expect { job.expand_params }.to raise_error Job::ParamError
    end
  end
end
