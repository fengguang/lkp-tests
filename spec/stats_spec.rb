require 'spec_helper'

describe 'stats' do
  yaml_files = Dir.glob "#{LKP_SRC}/stats/*.[0-9]*.yaml"
  yaml_files.each do |yaml_file|
    file = yaml_file.chomp '.yaml'
    it "invariance: #{file}" do
      script = File.basename(file.sub(/\.[0-9]+$/, ''))
      old_stat = File.read yaml_file
      if script =~ /^(kmsg|dmesg)$/
        new_stat = `#{LKP_SRC}/stats/#{script} #{file}`
      else
        new_stat = `#{LKP_SRC}/stats/#{script} < #{file}`
      end
      expect(new_stat).to eq old_stat
    end
  end
end
