require 'spec_helper'
require "#{LKP_SRC}/lib/stats"

describe 'stats' do
  describe 'scripts' do
    yaml_files = Dir.glob ["#{LKP_SRC}/spec/stats/*/[0-9]*.yaml"]
    yaml_files.each do |yaml_file|
      file = yaml_file.chomp '.yaml'
      it "invariance: #{file}" do
        script = File.basename(File.dirname(file))
        old_stat = File.read yaml_file
        new_stat = if script =~ /^(kmsg|dmesg|mpstat|fio)$/
                     `#{LKP_SRC}/stats/#{script} #{file}`
                   else
                     `#{LKP_SRC}/stats/#{script} < #{file}`
                   end
        expect(new_stat).to eq old_stat
      end
    end
  end

  describe 'kpi_stat_direction' do
    it 'should match the correct value' do
      change_percentage = 1
      a = 'aim9.add_float.ops_per_sec'
      b = 'phoronix-test-suite.aobench.0.seconds'
      c = 'aim9.test'

      expect(kpi_stat_direction(a, change_percentage)).to eq 'improvement'
      expect(kpi_stat_direction(b, change_percentage)).to eq 'regression'
      expect(kpi_stat_direction(c, change_percentage)).to eq 'undefined'
    end
  end
end
