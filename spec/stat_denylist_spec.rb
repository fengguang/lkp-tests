require 'spec_helper'

describe 'etc/stat-denylist' do
  it 'does not deny allowed stat' do
    denylist = File.readlines("#{LKP_SRC}/etc/stat-denylist").map(&:chomp)
    allowlist = File.readlines("#{LKP_SRC}/etc/stat-allowlist")
                    .map(&:chomp)
                    .map { |stat| stat.tr('\\', '').sub(/^\^/, '') }

    actual = denylist.select do |denied_stat|
      denied_stat = Regexp.new(denied_stat)
      allowlist.any? { |stat| stat =~ denied_stat }
    end

    expect(actual).to be_empty
  end
end
