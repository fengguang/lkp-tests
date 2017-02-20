require 'spec_helper'

describe 'libhugetlbfs' do
  describe 'stats' do
    let(:stats_script) { "#{LKP_SRC}/stats/libhugetlbfs" }

    it 'stats test results' do
      stdout = <<EOF
shm-fork 10 25 (2M: 32):	PASS
shm-fork 10 25 (2M: 64):	PASS
shm-perms (2M: 32):	Bad configuration: Must have at least 32 free hugepages
shm-perms (2M: 64):	Bad configuration: Must have at least 32 free hugepages
HUGETLB_ELFMAP=RW linkhuge_rw (2M: 32):
HUGETLB_ELFMAP=RW linkhuge_rw (2M: 64):
HUGETLB_SHARE=1 HUGETLB_ELFMAP=R linkhuge_rw (2M: 32):	FAIL	small_const is not hugepage
HUGETLB_SHARE=1 HUGETLB_ELFMAP=R linkhuge_rw (2M: 64):	FAIL	small_const is not hugepage
********** TEST SUMMARY
*                      2M
*                      32-bit 64-bit
*     Total testcases:   110    113
EOF
      actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
      expect(actual).to eq(['32bit.shm-fork_10_25.pass: 1', '64bit.shm-fork_10_25.pass: 1', '32bit.shm-perms.bad_configuration: 1', '64bit.shm-perms.bad_configuration: 1',\
                            '32bit.hugetlb_elfmap=rw_linkhuge_rw.killed_by_signal: 1', '64bit.hugetlb_elfmap=rw_linkhuge_rw.killed_by_signal: 1',\
                            '32bit.hugetlb_share=1_hugetlb_elfmap=r_linkhuge_rw.fail: 1', '64bit.hugetlb_share=1_hugetlb_elfmap=r_linkhuge_rw.fail: 1', 'total_test: 223'])
    end
  end
end
