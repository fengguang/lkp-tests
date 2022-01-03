LKP_SRC = ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require 'spec_helper'
require "#{LKP_SRC}/lib/lkp_path"

describe 'etc/stat-denylist' do
  it 'does not deny allowed stat' do
    denylist = File.readlines(LKP::Path.src('etc', 'stat-denylist')).map(&:chomp)
    allowlist = File.readlines(LKP::Path.src('etc', 'stat-allowlist'))
                    .map(&:chomp)
                    .map { |stat| stat.tr('\\', '').sub(/^\^/, '') }

    actual = denylist.select do |denied_stat|
      denied_stat = Regexp.new(denied_stat)
      allowlist.any? { |stat| stat =~ denied_stat }
    end

    expect(actual).to be_empty
  end
end
