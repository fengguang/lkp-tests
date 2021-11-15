#!/bin/bash

. $LKP_SRC/lib/debug.sh
. $LKP_SRC/lib/tests/update-llvm.sh
. $LKP_SRC/lib/env.sh
. $LKP_SRC/lib/reproduce-log.sh

prepare_tests()
{
	prepare_test_env || die "prepare test env failed"

	# Only update llvm for bpf test
	[ "$group" = "bpf" -o "$group" = "net" -o "$group" = "tc-testing" ] && {
		cd / && {
			prepare_for_llvm || die "install newest llvm failed"
	    }
	}

	cd $linux_selftests_dir/tools/testing/selftests || die

	prepare_for_test

	prepare_for_selftest

	[ -n "$selftest_mfs" ] || die "empty selftest_mfs"
}

make_group_tests()
{
	# Disable parallel make temporary since there is a bug in
	# current parallel make -C kvm
	# nr_procs=$(nproc)
	# nr_procs=${nr_procs:-2}
	# log_cmd make -j$nr_procs -C $subtest 2>&
	log_cmd make -C $subtest 2>&1
}

# it will touch the Makefile, overwrite target
#@@ -40,6 +40,9 @@ TEST_GEN_PROGS = reuseport_bpf reuseport_bpf_cpu reuseport_bpf_numa
# TEST_GEN_PROGS += reuseport_dualstack reuseaddr_conflict tls
#
#  TEST_FILES := settings
#
#   KSFT_KHDR_INSTALL := 1
#  +TEST_GEN_PROGS =
#  +TEST_GEN_FILES =
#  +TEST_PROGS = tls
#    include ../lib.mk
keep_only_specific_test()
{
	local makefile=$subtest/Makefile

	[[ "$test" ]] || return
	[[ -f $makefile ]] || return

	# keep specific $test only
	sed -i "/^include .*\/lib.mk/i TEST_GEN_PROGS =" $makefile
	sed -i "/^include .*\/lib.mk/i TEST_GEN_FILES =" $makefile
	sed -i "/^include .*\/lib.mk/i TEST_PROGS = $test" $makefile

	[[ $test = "fcnal-test.sh" ]] && {
		echo "timeout=3600" >> $subtest/settings
	}
}

run_tests()
{
	local selftest_mfs=$@

	# kselftest introduced runner.sh since kernel commit 42d46e57ec97 "selftests: Extract single-test shell logic from lib.mk"
	[[ -e kselftest/runner.sh ]] && log_cmd sed -i 's/default_timeout=45/default_timeout=300/' kselftest/runner.sh

	for mf in $selftest_mfs; do
		subtest=${mf%/Makefile}
		check_subtest || continue

		(
		check_makefile $subtest || log_cmd make TARGETS=$subtest 2>&1

		fixup_subtest $subtest || exit

		make_group_tests

		keep_only_specific_test

		# vmalloc performance and stress, can not use 'make run_tests' to run
		if [[ $test =~ ^vmalloc\-(performance|stress)$ ]]; then
			log_cmd vm/test_vmalloc.sh ${test##vmalloc-} 2>&1
			log_cmd dmesg | grep -E '(Summary|All test took)' 2>&1
		else
			log_cmd make run_tests -C $subtest 2>&1
		fi

		cleanup_subtest
		)
	done
}
