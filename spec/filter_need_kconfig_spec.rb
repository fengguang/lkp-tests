require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require "#{LKP_SRC}/lib/job"

describe 'filter/need_kconfig.rb' do
  before(:all) do
    @tmp_dir = Dir.mktmpdir(nil, '/tmp')
    FileUtils.chmod 'go+rwx', @tmp_dir

    @test_job_file = "#{@tmp_dir}/test.yaml".freeze

    File.open(File.join(@tmp_dir, 'context.yaml'), 'w') do |f|
      f.write({'rc_tag' => 'v5.0-rc1'}.to_yaml)
    end
    File.open(File.join(@tmp_dir, '.config'), 'w') do |f|
      f.write('CONFIG_XXXX=y')
    end
  end

  after(:all) do
    FileUtils.remove_entry @tmp_dir
  end

  context 'when CONFIG_XXXX is built-in in kernel' do
    context 'when kernel version is within limit' do
      it 'does not filter the job' do
        File.open(@test_job_file, 'w') do |f|
          f.puts <<~EOF
            need_kconfig: CONFIG_XXXX=y ~ '<= v5.0' # support kernel <=v5.0
            kernel: #{@tmp_dir}/vmlinuz
          EOF
        end
        # Job.open can filter comments(e.g. # support kernel xxx)
        job = Job.open(@test_job_file)
        job.expand_params
      end
    end

    context 'when kernel version outside limit' do
      it 'does not filter the job' do
        File.open(@test_job_file, 'w') do |f|
          f.puts <<~EOF
            need_kconfig: CONFIG_XXXX=y ~ '>= v5.1-rc1' # support kernel >=v5.1-rc1
            kernel: #{@tmp_dir}/vmlinuz
          EOF
        end
        job = Job.open(@test_job_file)
        job.expand_params
      end
    end

    context 'when kernel version limit is not defined' do
      it 'does not filter the job' do
        File.open(@test_job_file, 'w') do |f|
          f.write({'need_kconfig' => 'CONFIG_XXXX=y', 'kernel' => "#{@tmp_dir}/vmlinuz"}.to_yaml)
        end
        job = Job.open(@test_job_file)
        job.expand_params
      end
    end
  end

  context 'when CONFIG_YYYY is not built in kernel' do
    context 'when kernel version is within limit' do
      it 'filters the job' do
        File.open(@test_job_file, 'w') do |f|
          f.puts <<~EOF
            need_kconfig: CONFIG_YYYY=m ~ '<= v5.0' # support kernel <=v5.0
            kernel: #{@tmp_dir}/vmlinuz
          EOF
        end
        job = Job.open(@test_job_file)
        expect { job.expand_params }.to raise_error Job::ParamError
      end
    end

    context 'when kernel version is outside limit' do
      it 'does not filter the job' do
        File.open(@test_job_file, 'w') do |f|
          f.puts <<~EOF
            need_kconfig: CONFIG_YYYY=m ~ '>= v5.1-rc1' # support kernel >=v5.1-rc1
            kernel: #{@tmp_dir}/vmlinuz
          EOF
        end
        job = Job.open(@test_job_file)
        job.expand_params
      end
    end

    context 'when kernel version limit is not defined' do
      it 'filters the job' do
        File.open(@test_job_file, 'w') do |f|
          f.write({'need_kconfig' => 'CONFIG_YYYY=m', 'kernel' => "#{@tmp_dir}/vmlinuz"}.to_yaml)
        end
        job = Job.open(@test_job_file)
        expect { job.expand_params }.to raise_error Job::ParamError
      end
    end

    context 'when CONFIG_YYYY is not defined' do
      it 'does not filter the job' do
        File.open(@test_job_file, 'w') do |f|
          f.write({'kernel' => "#{@tmp_dir}/vmlinuz"}.to_yaml)
        end
        job = Job.open(@test_job_file)
        job.expand_params
      end
    end
  end
end
