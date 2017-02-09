require 'spec_helper'
require 'yaml'
require "#{LKP_SRC}/lib/erb"

erb_yaml = File.expand_path('../erb_spec.yaml', __FILE__)
expects = YAML.load expand_erb(File.read(erb_yaml))

describe 'ERB template in YAML' do
  expects.each do |k, v|
    next unless k.instance_of?(Symbol)
    next unless v.instance_of?(Array) && v.size == 2

    it k.to_s do
      expect(v[0]).to eq v[1]
    end
  end
end
