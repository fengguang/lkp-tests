require 'spec_helper'

describe 'xfstests' do
  describe 'stats' do
    let(:stats_script) { "#{LKP_SRC}/stats/xfstests" }

    it 'stats test results' do
      stdout = <<EOF
_check_generic_filesystem: filesystem on /dev/vdd is inconsistent (see /lkp/benchmarks/xfstests/results//generic/084.full)
generic/085   21s
Ran: generic/001 generic/002
Not run: generic/026 generic/042
Failures: generic/084
Failed 1 of 59 tests
EOF
      actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
      expect(actual).to eq(['generic.084.inconsistent_fs: 1', 'generic.085.seconds: 21', 'generic.001.pass: 1', 'generic.002.pass: 1', 'generic.026.skip: 1', 'generic.042.skip: 1', 'generic.084.fail: 1', 'total_test: 4'])
    end
  end
end
