require 'spec_helper'

describe 'nvml' do
  describe 'stats' do
    let(:stats_script) { "#{LKP_SRC}/stats/nvml" }

    context 'when given results with setup and non-setup' do
      it 'stats test results without setup' do
        stdout = <<EOF
2017-03-03 16:55:27 ./RUNTESTS vmmalloc_calloc
error: PMEM_FS_DIR=/fs/pmem0 does not point to a PMEM device
RUNTESTS: stopping: vmmalloc_calloc/TEST0 failed, TEST=check FS=any BUILD=debug
2017-03-03 16:55:27 ./RUNTESTS vmmalloc_check_allocations
error: PMEM_FS_DIR=/fs/pmem0 does not point to a PMEM device
RUNTESTS: stopping: vmmalloc_check_allocations/TEST0 failed, TEST=check FS=any BUILD=debug
EOF
        actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
        expect(actual).to eq(['vmmalloc_calloc_TEST0_any_debug.fail: 1', 'vmmalloc_check_allocations_TEST0_any_debug.fail: 1', 'total_test: 2'])
      end

      it 'stats test results with setup' do
        stdout = <<EOF
util_poolset_parse/TEST0: SETUP (check/none/static-nondebug)
util_poolset_parse/TEST0: START: util_poolset_parse
util_poolset_parse/TEST0: FAIL
2017-03-03 16:55:27 ./RUNTESTS vmmalloc_calloc
error: PMEM_FS_DIR=/fs/pmem0 does not point to a PMEM device
RUNTESTS: stopping: vmmalloc_calloc/TEST1 failed, TEST=check FS=any BUILD=debug
2017-03-03 16:55:27 ./RUNTESTS vmmalloc_check_allocations
error: PMEM_FS_DIR=/fs/pmem0 does not point to a PMEM device
RUNTESTS: stopping: vmmalloc_check_allocations/TEST0 failed, TEST=check FS=any BUILD=debug
EOF
        actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
        expect(actual).to eq(['util_poolset_parse_TEST0_none_static-nondebug.fail: 1', 'vmmalloc_calloc_TEST1_any_debug.fail: 1', 'vmmalloc_check_allocations_TEST0_any_debug.fail: 1', 'total_test: 3'])
      end
    end
  end
end
