require 'spec_helper'
require "#{LKP_SRC}/lib/dmesg"

describe 'Kmsg' do
  describe 'stats' do
    files = Dir.glob "#{LKP_SRC}/spec/kmsg/kmsg-*"
    files.each do |file|
      it 'invariance: #{file}' do
        old_stat = File.read file.sub('kmsg-', 'kmsg.')
        new_stat = `#{LKP_SRC}/stats/kmsg #{file}`
        expect(new_stat).to eq old_stat
      end
    end
  end
end
