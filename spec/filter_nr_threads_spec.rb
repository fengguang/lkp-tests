require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require "#{LKP_SRC}/lib/job"

describe 'filter/nr_threads' do
  before(:all) do
    @tmp_dir = Dir.mktmpdir(nil, '/tmp')
    FileUtils.chmod 'go+rwx', @tmp_dir
    @test_yaml_file = "#{@tmp_dir}/test.yaml".freeze
  end

  after(:all) do
    FileUtils.remove_entry @tmp_dir
  end

  context 'when nr_threads is defined in top level with valid value'
  it 'does not filter the job' do
    File.open(@test_yaml_file, 'w') do |f|
      f.write({ 'testcase' => 'testcase', 'nr_threads' => 1 }.to_yaml)
    end
    job = Job.open(@test_yaml_file)
    job.expand_params
  end

  context 'when nr_threads is defined in top level with invalid value'
  it 'filters the job' do
    File.open(@test_yaml_file, 'w') do |f|
      f.write({ 'testcase' => 'testcase', 'nr_threads' => 0 }.to_yaml)
    end
    job = Job.open(@test_yaml_file)
    expect { job.expand_params }.to raise_error Job::ParamError
  end

  context 'when nr_threads is defined in second level with valid value'
  it 'does not filter the job' do
    File.open(@test_yaml_file, 'w') do |f|
      f.write({ 'testcase' => 'testcase', 'sleep' => { 'nr_threads' => 1 } }.to_yaml)
    end
    job = Job.open(@test_yaml_file)
    job.expand_params
  end

  context 'when nr_threads is defined in second level with invalid value'
  it 'does not filter the job' do
    File.open(@test_yaml_file, 'w') do |f|
      f.write({ 'testcase' => 'testcase', 'sleep' => { 'nr_threads' => 0 } }.to_yaml)
    end
    job = Job.open(@test_yaml_file)
    job.expand_params
  end
end
