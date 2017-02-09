require 'spec_helper'

describe 'stats' do
  files = Dir.glob "#{LKP_SRC}/spec/stats/*:[0-9]*"
  files.each do |file|
    it "invariance: #{file}" do
      script = file.split(/[\/:]/)[-2]
      old_stat = File.read file.sub(':', '.')
      new_stat = `#{LKP_SRC}/stats/#{script} < #{file}`
      expect(new_stat).to eq old_stat
    end
  end
end
