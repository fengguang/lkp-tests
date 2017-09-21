require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'shellwords'

describe 'log_cmd' do
  let(:log_cmd) { "#{LKP_SRC}/bin/log_cmd " }
  before(:all) do
    @pwd = Dir.pwd
    @tmp_dir = Dir.mktmpdir
    FileUtils.chmod 'go+rwx', @tmp_dir
    Dir.chdir(@tmp_dir)
  end

  it 'creates multi dirs' do
    was_good = system(log_cmd + 'mkdir a b')
    expect(was_good).to be(true)
    expect(Dir).to be_exist('a')
    expect(Dir).to be_exist('b')
    Dir.delete('a')
    Dir.delete('b')
  end

  it 'creates dir with space' do
    was_good = system(log_cmd + 'mkdir "a b"')
    expect(was_good).to be(true)
    expect(Dir).to be_exist('a b')
    Dir.delete('a b')
  end

  it 'creates dir with single quote' do
    dir = '"a'
    was_good = system(log_cmd + 'mkdir ' + Shellwords.escape(dir).to_s)
    expect(was_good).to be(true)
    expect(Dir).to be_exist('"a')
    Dir.delete('"a')
  end

  it 'creates dir with space and double quotes' do
    dir = '"a b"'
    was_good = system(log_cmd + 'mkdir ' + Shellwords.escape(dir).to_s)
    expect(was_good).to be(true)
    expect(Dir).to be_exist('"a b"')
    Dir.delete('"a b"')
  end

  it 'execute built-in command' do
    was_good = system(log_cmd + 'cd .')
    expect(was_good).to be(true)
  end

  after(:all) do
    Dir.delete(@tmp_dir)
    Dir.chdir(@pwd)
  end
end
