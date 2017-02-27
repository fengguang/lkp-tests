require 'spec_helper'

describe 'kernel_selftests' do
  describe 'stats' do
    let(:stats_script) { "#{LKP_SRC}/stats/kernel_selftests" }

    it 'stats test results' do
      stdout = <<EOF
make: Entering directory '/usr/src/linux-selftests-x86_64-rhel-7.2-a121103c922847ba5010819a3f250f1f7fc84ab8/tools/testing/selftests/bpf'
selftests: test_kmod.sh [FAIL]
make: Leaving directory '/usr/src/linux-selftests-x86_64-rhel-7.2-a121103c922847ba5010819a3f250f1f7fc84ab8/tools/testing/selftests/bpf'

make: Entering directory '/usr/src/linux-selftests-x86_64-rhel-7.2-a121103c922847ba5010819a3f250f1f7fc84ab8/tools/testing/selftests/sysctl'
selftests: run_numerictests [PASS]
selftests: run_stringtests [PASS]
make: Leaving directory '/usr/src/linux-selftests-x86_64-rhel-7.2-a121103c922847ba5010819a3f250f1f7fc84ab8/tools/testing/selftests/sysctl'
EOF
      actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
      expect(actual).to eq(['bpf.test_kmod.sh.fail: 1', 'sysctl.run_numerictests.pass: 1', 'sysctl.run_stringtests.pass: 1', 'total_test: 3'])
    end

    it 'stats compilation fail' do
      stdout = <<EOF
2017-01-30 23:57:13 make run_tests -C x86
make: Entering directory '/usr/src/linux-selftests-x86_64-rhel-7.2-a121103c922847ba5010819a3f250f1f7fc84ab8/tools/testing/selftests/x86'
gcc -m64 -o single_step_syscall_64 -O2 -g -std=gnu99 -pthread -Wall  single_step_syscall.c -lrt -ldl
gcc -m64 -o sysret_ss_attrs_64 -O2 -g -std=gnu99 -pthread -Wall  sysret_ss_attrs.c thunks.S -lrt -ldl
Makefile:47: recipe for target 'sysret_ss_attrs_64' failed
make: Leaving directory '/usr/src/linux-selftests-x86_64-rhel-7.2-a121103c922847ba5010819a3f250f1f7fc84ab8/tools/testing/selftests/x86'
EOF
      actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
      expect(actual).to eq(['x86.make_fail: 1'])
    end

    it 'stats mqueue result' do
      stdout = <<EOF
        Test #2b: Time send/recv message, queue full, increasing prio
:
                (100000 iterations)
                Filling queue...done.           0.23502215s
                Testing...done.
                Send msg:                       0.48443412s total time
                                                484 nsec/msg
                Recv msg:                       0.42612149s total time
                                                426 nsec/msg
                Draining queue...done.          0.17199103s

        Test #2c: Time send/recv message, queue full, decreasing prio
:
                (100000 iterations)
                Filling queue...done.           0.23586541s
                Testing...done.
                Send msg:                       0.49698382s total time
                                                496 nsec/msg
                Recv msg:                       0.42457983s total time
                                                424 nsec/msg
                Draining queue...done.          0.17599680s
EOF
      actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
      expect(actual).to eq(["mqueue.nsec_per_msg: #{(484 + 426 + 496 + 424) / 4}", 'total_test: 1'])
    end

    it 'stats futex result' do
      stdout = <<EOF
make: Entering directory '/usr/src/linux-selftests-x86_64-rhel-7.2-d5adbfcd5f7bcc6fa58a41c5c5ada0e5c826ce2c/tools/testing/selftests/futex'
futex_requeue_pi: Test requeue functionality
	Arguments: broadcast=0 locked=0 owner=0 timeout=0ns
Result:  PASS
futex_requeue_pi: Test requeue functionality
	Arguments: broadcast=1 locked=0 owner=0 timeout=0ns
Result:  PASS

futex_requeue_pi_mismatched_ops: Detect mismatched requeue_pi operations
Result:  PASS

futex_requeue_pi_signal_restart: Test signal handling during requeue_pi
	Arguments: <none>
Result:  PASS

make: Leaving directory '/usr/src/linux-selftests-x86_64-rhel-7.2-d5adbfcd5f7bcc6fa58a41c5c5ada0e5c826ce2c/tools/testing/selftests/futex'
EOF
      actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
      expect(actual).to eq(['futex.futex_requeue_pi.broadcast=0_locked=0_owner=0_timeout=0ns.pass: 1', 'futex.futex_requeue_pi.broadcast=1_locked=0_owner=0_timeout=0ns.pass: 1',\
                            'futex.futex_requeue_pi_mismatched_ops.pass: 1', 'futex.futex_requeue_pi_signal_restart.pass: 1', 'total_test: 4'])
    end

    it 'stats memory-hotplug pass result' do
      stdout = <<EOF
make: Entering directory '/usr/src/linux-selftests-x86_64-rhel-7.2-d5adbfcd5f7bcc6fa58a41c5c5ada0e5c826ce2c/tools/testing/selftests/memory-hotplug'
./mem-on-off-test.sh -r 2 || echo "selftests: memory-hotplug [FAIL]"
Test scope: 2% hotplug memory
	 online all hotplug memory in offline state
	 offline 2% hotplug memory in online state
	 online all hotplug memory in offline state
online-offline 49
online-offline 5
online-offline 53
offline-online 49
offline-online 5
offline-online 53
make: Leaving directory '/usr/src/linux-selftests-x86_64-rhel-7.2-d5adbfcd5f7bcc6fa58a41c5c5ada0e5c826ce2c/tools/testing/selftests/memory-hotplug'
EOF
      actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
      expect(actual).to eq(['memory-hotplug.mem-on-off-test.sh.pass: 1', 'total_test: 1'])
    end

    it 'stats memory-hotplug fail result' do
      stdout = <<EOF
make: Entering directory '/usr/src/linux-selftests-x86_64-rhel-7.2-d5adbfcd5f7bcc6fa58a41c5c5ada0e5c826ce2c/tools/testing/selftests/memory-hotplug'
./mem-on-off-test.sh -r 2 || echo "selftests: memory-hotplug [FAIL]"
Test scope: 2% hotplug memory
      online all hotplug memory in offline state
online-offline 49
online-offline 5
selftests: memory-hotplug [FAIL]
make: Leaving directory '/usr/src/linux-selftests-x86_64-rhel-7.2-d5adbfcd5f7bcc6fa58a41c5c5ada0e5c826ce2c/tools/testing/selftests/memory-hotplug'
EOF
      actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
      expect(actual).to eq(['memory-hotplug.mem-on-off-test.sh.fail: 1', 'total_test: 1'])
    end

    it 'stats memory-hotplug make fail' do
      stdout = <<EOF
make: Entering directory '/usr/src/linux-selftests-x86_64-rhel-7.2-d5adbfcd5f7bcc6fa58a41c5c5ada0e5c826ce2c/tools/testing/selftests/memory-hotplug'
make: recipe for target failed
make: Leaving directory '/usr/src/linux-selftests-x86_64-rhel-7.2-d5adbfcd5f7bcc6fa58a41c5c5ada0e5c826ce2c/tools/testing/selftests/memory-hotplug'
EOF
      actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
      expect(actual).to eq(['memory-hotplug.make_fail: 1'])
    end

    it 'stats mount pass result' do
      stdout = <<EOF
make: Entering directory '/usr/src/linux-selftests-x86_64-rhel-7.2-69973b830859bc6529a7a0468ba0d80ee5117826/tools/testing/selftests/mount'
gcc -Wall -O2 unprivileged-remount-test.c -o unprivileged-remount-test
if [ -f /proc/self/uid_map ] ; then ./unprivileged-remount-test ; else echo "WARN: No /proc/self/uid_map exist, test skipped." ; fi
make: Leaving directory '/usr/src/linux-selftests-x86_64-rhel-7.2-69973b830859bc6529a7a0468ba0d80ee5117826/tools/testing/selftests/mount'
EOF
      actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
      expect(actual).to eq(['mount.unprivileged-remount-test.pass: 1', 'total_test: 1'])
    end

    it 'stats mount fail result' do
      stdout = <<EOF
make: Entering directory '/usr/src/linux-selftests-x86_64-rhel-7.2-69973b830859bc6529a7a0468ba0d80ee5117826/tools/testing/selftests/mount'
gcc -Wall -O2 unprivileged-remount-test.c -o unprivileged-remount-test
if [ -f /proc/self/uid_map ] ; then ./unprivileged-remount-test ; else echo "WARN: No /proc/self/uid_map exist, test skipped." ; fi
Mount flags unexpectedly changed after remount
make: Leaving directory '/usr/src/linux-selftests-x86_64-rhel-7.2-69973b830859bc6529a7a0468ba0d80ee5117826/tools/testing/selftests/mount'
EOF
      actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
      expect(actual).to eq(['mount.unprivileged-remount-test.fail: 1', 'total_test: 1'])
    end

    it 'stats mount skip result' do
      stdout = <<EOF
make: Entering directory '/usr/src/linux-selftests-x86_64-rhel-7.2-69973b830859bc6529a7a0468ba0d80ee5117826/tools/testing/selftests/mount'
gcc -Wall -O2 unprivileged-remount-test.c -o unprivileged-remount-test
if [ -f /proc/self/uid_map ] ; then ./unprivileged-remount-test ; else echo "WARN: No /proc/self/uid_map exist, test skipped." ; fi
WARN: No /proc/self/uid_map exist, test skipped.
make: Leaving directory '/usr/src/linux-selftests-x86_64-rhel-7.2-69973b830859bc6529a7a0468ba0d80ee5117826/tools/testing/selftests/mount'
EOF
      actual = `echo "#{stdout}" | #{stats_script}`.split("\n")
      expect(actual).to eq(['mount.unprivileged-remount-test.skip: 1', 'total_test: 1'])
    end
  end
end
