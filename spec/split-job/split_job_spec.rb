require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require "#{LKP_SRC}/lib/bash"
require "#{LKP_SRC}/lib/yaml"

describe 'lkp-split-job' do
  before(:all) do
    @tmp_src_dir = Dir.mktmpdir(nil, '/tmp')

    `rsync -aix #{LKP_SRC}/ #{@tmp_src_dir}`
    `rsync -aix #{LKP_SRC}/spec/split-job/tests #{LKP_SRC}/spec/split-job/include #{@tmp_src_dir}/`
  end

  after(:all) do
    FileUtils.rm_rf @tmp_src_dir
  end

  before(:each) do
    @tmp_dir = Dir.mktmpdir(nil, '/tmp')
  end

  after(:each) do
    FileUtils.rm_rf @tmp_dir
  end

  it "split job['split-job']['test'] only" do
    Dir.chdir(@tmp_src_dir) do
      `LKP_SRC=#{@tmp_src_dir} #{@tmp_src_dir}/bin/lkp split-job -t lkp-tbox -o #{@tmp_dir} spec/split-job/1.yaml`

      Dir[File.join(@tmp_dir, '1-*.yaml')].each do |actual_yaml|
        `sed -i 's/:#! /#!/g' #{actual_yaml}`
        actual = YAML.load_file(actual_yaml)
        expect = YAML.load_file("#{LKP_SRC}/spec/split-job/#{File.basename(actual_yaml)}")

        expect(actual).to eq expect
      end
    end
  end

  it "split job['split-job']['test'] and job['split-job']['group']" do
    Dir.chdir(@tmp_src_dir) do
      `LKP_SRC=#{@tmp_src_dir} #{@tmp_src_dir}/bin/lkp split-job -t lkp-tbox -o #{@tmp_dir} spec/split-job/2.yaml`
      Dir[File.join(@tmp_dir, '2-*.yaml')].each do |actual_yaml|
        `sed -i 's/:#! /#!/g' #{actual_yaml}`
        actual = YAML.load_file(actual_yaml)
        expect = YAML.load_file("#{LKP_SRC}/spec/split-job/#{File.basename(actual_yaml)}")

        expect(actual).to eq expect
      end
    end
  end
end
