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

		log_cmd make run_tests -C $subtest 2>&1

		cleanup_subtest
		)
	done
}
