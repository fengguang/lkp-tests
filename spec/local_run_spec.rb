#!/usr/bin/env ruby
LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'fileutils'
require 'tmpdir'

describe 'local run' do
  before(:all) do
    @tmp_dir = Dir.mktmpdir
    FileUtils.chmod 'go+rwx', @tmp_dir
    @tmp_file = "#{@tmp_dir}/run-env-tmp.rb"
    FileUtils.cp "#{LKP_SRC}/lib/run-env.rb", @tmp_file
    s = ''
    File.open(@tmp_file, 'r') do |f|
      f.each_line { |l| s += l.gsub(/\#{LKP_SRC}\/hosts\//, "#{@tmp_dir}/") }
      f.rewind
    end
    File.open(@tmp_file, 'w') { |f| f.write s }

    require @tmp_file
    @hostname = `hostname`.chomp
    @hostfile = "#{@tmp_dir}/#{@hostname}"
  end

  describe 'local_run' do
    it 'first run without host file or ENV' do
      expect(local_run?).to eq(false)
      expect(result_prefix).to eq('')
    end

    it 'first run with host file with local_run: 1' do
      File.open(@hostfile, 'w') { |file| file.write("local_run: 1\n") }
      expect(local_run?).to eq(true)
      expect(result_prefix).to eq('/lkp')
    end

    it 'first run with host file with local_run: 0' do
      File.open(@hostfile, 'w') { |file| file.write("local_run: 0\n") }
      expect(local_run?).to eq(false)
      expect(result_prefix).to eq('')
    end

    it 'first run with host file without local_run' do
      File.open(@hostfile, 'w') { |file| file.write("hdd_partitions: \nssd_partitions: \n") }
      local_run?
      expect(local_run?).to eq(false)
      expect(result_prefix).to eq('')
    end

    it 'second run without host file or ENV' do
      local_run?
      expect(local_run?).to eq(false)
      expect(result_prefix).to eq('')
    end

    it 'second run with host file with local_run: 1' do
      File.open(@hostfile, 'w') { |file| file.write("local_run: 1\n") }
      local_run?
      expect(local_run?).to eq(true)
      expect(result_prefix).to eq('/lkp')
    end

    it 'second run with host file with local_run: 0' do
      File.open(@hostfile, 'w') { |file| file.write("local_run: 0\n") }
      local_run?
      expect(local_run?).to eq(false)
      expect(result_prefix).to eq('')
    end

    it 'second run with host file without local_run' do
      File.open(@hostfile, 'w') { |file| file.write("hdd_partitions: \nssd_partitions: \n") }
      local_run?
      expect(local_run?).to eq(false)
      expect(result_prefix).to eq('')
    end

    after(:each) do
      FileUtils.rm_f(@hostfile)
      ENV[LOCAL_RUN_ENV] = nil
      ENV['RESULT_PREFIX'] = nil
    end
  end

  describe 'local_run ENV 0' do
    before(:each) do
      ENV[LOCAL_RUN_ENV] = '0'
    end

    it 'first run without host file' do
      expect(local_run?).to eq(false)
      expect(result_prefix).to eq('')
    end

    it 'first run with host file of local_run: 1' do
      File.open(@hostfile, 'w') { |file| file.write("local_run: 1\n") }
      expect(local_run?).to eq(false)
      expect(result_prefix).to eq('')
    end

    it 'first run with host file of local_run: 0' do
      File.open(@hostfile, 'w') { |file| file.write("local_run: 0\n") }
      expect(local_run?).to eq(false)
      expect(result_prefix).to eq('')
    end

    it 'first run with host file without local_run' do
      File.open(@hostfile, 'w') { |file| file.write("hdd_partitions: \nssd_partitions: \n") }
      expect(local_run?).to eq(false)
      expect(result_prefix).to eq('')
    end

    after(:each) do
      FileUtils.rm_f(@hostfile)
      ENV[LOCAL_RUN_ENV] = nil
      ENV['RESULT_PREFIX'] = nil
    end
  end

  describe 'local_run ENV 1' do
    before(:each) do
      ENV[LOCAL_RUN_ENV] = '1'
    end

    it 'first run without host file' do
      expect(local_run?).to eq(true)
      expect(result_prefix).to eq('/lkp')
    end

    it 'first run with host file of local_run: 1' do
      File.open(@hostfile, 'w') { |file| file.write("local_run: 1\n") }
      expect(local_run?).to eq(true)
      expect(result_prefix).to eq('/lkp')
    end

    it 'first run with host file of local_run: 0' do
      File.open(@hostfile, 'w') { |file| file.write("local_run: 0\n") }
      expect(local_run?).to eq(true)
      expect(result_prefix).to eq('/lkp')
    end

    it 'first run with host file without local_run' do
      File.open(@hostfile, 'w') { |file| file.write("hdd_partitions: \nssd_partitions: \n") }
      expect(local_run?).to eq(true)
      expect(result_prefix).to eq('/lkp')
    end

    after(:each) do
      FileUtils.rm_f @hostfile
      ENV[LOCAL_RUN_ENV] = nil
      ENV['RESULT_PREFIX'] = nil
    end
  end

  after(:all) do
    FileUtils.remove_entry @tmp_dir
  end
end
