require 'json'
require 'yaml'
require 'spec_helper'
require "#{LKP_SRC}/lib/job"

describe 'pp' do
  yaml_files = Dir.glob("#{LKP_SRC}/spec/pp/*.yaml")
  yaml_files.each do |file|
    it 'check' do
      # get input
      job = Job.new()
      job.load(file)
      job.add_pp()
      input = Hash.new()
      input["pp"] = job.to_hash["pp"]
      # get output
      name = File.basename(file, '.yaml')
      output_file = "#{LKP_SRC}/spec/pp/#{name}.pp"
      output = YAML.load_file(output_file)
      # check
      expect(input).to eq output
    end
  end
end
