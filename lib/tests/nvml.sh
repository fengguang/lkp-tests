#!/bin/bash

check_param()
{
	local casename=$1

	log_cmd cd $BENCHMARK_ROOT/$casename/src/test || die "Can not find $casename/src/test dir"

	if [[ "$test" = "non-pmem" ]] || [[ "$test" = "pmem" ]] || [[ "$test" = "none" ]]; then
		local tmp_dir=$(mktemp -d)
		echo "NON_PMEM_FS_DIR=$tmp_dir" > testconfig.sh
		echo "PMEM_FS_DIR=/fs/pmem0" >> testconfig.sh
		mkdir -p /fs/pmem0
	else
		die "Parameter \"test\" is wrong"
	fi

	[[ -n "$group" ]] || die "Parameter \"group\" is empty"

	testcases=$(ls -d "$group"_* 2>/dev/null)

	# Some testcase is contianed in folder named by $group (such as traces).
	# Adding it into testcases. We think it's a testcase if there is a TEST0 in the folder.
	[[ -f "$group/TEST0" ]] && testcases+=" $group"
	[[ -n "$testcases" ]] || die "Parameter \"group\" is invalid"
}

setup_compiler()
{
	log_cmd export CC=clang
	log_cmd export CXX=clang++
}

build_env()
{
	local casename=$1

	log_cmd cd $BENCHMARK_ROOT/$casename

	setup_compiler

	# All C++ container tests need customized version of libc --libc++ to compile. So specify the path of libc++ to make.
	log_cmd make EXTRA_CFLAGS=-DUSE_VALGRIND USE_LLVM_LIBCPP=1 LIBCPP_INCDIR=/usr/local/libcxx/include/c++/v1/ LIBCPP_LIBDIR=/usr/local/libcxx/lib || return
	log_cmd make EXTRA_CFLAGS=-DUSE_VALGRIND USE_LLVM_LIBCPP=1 LIBCPP_INCDIR=/usr/local/libcxx/include/c++/v1/ LIBCPP_LIBDIR=/usr/local/libcxx/lib test || return
}

can_skip_copy_source()
{
	[ "$LKP_LOCAL_RUN" != "1" ] &&
	[ "$do_not_reboot_for_same_kernel" = "1" ] &&
	[ "$testcase" = "nvml-unit-tests" ] &&
	[ -f $BENCHMARK_ROOT/$testcase/lkp_skip_copy.$nvml_commit ]
}

can_skip_sync_remote()
{
	can_skip_copy_source &&
	[ -f $BENCHMARK_ROOT/$testcase/skip_sync_remote.$nvml_commit ]
}

enable_remote_node()
{
	local casename=$1

	log_cmd cd $BENCHMARK_ROOT/$casename/src/test || die "Can not find $casename/src/test dir"

	# To fix no nodes provide. It takes another machines as remote nodes. We can use 
	# localhost as remote node but need to do some configs as below.
	# reference on follow link
	# https://github.com/pmem/nvml/blob/3ab708efad653aeda0bcbc6b8d2b61d9ba9d5310/utils/docker/configure-tests.sh#L53
	for n in {0..3}
	do
		echo "NODE[$n]=127.0.0.1" >> testconfig.sh
		echo "NODE_WORKING_DIR[$n]=/tmp/node$n" >> testconfig.sh
		echo "NODE_ADDR[$n]=127.0.0.1" >> testconfig.sh
		echo "NODE_ENV[$n]=\"PMEM_IS_PMEM_FORCE=1\"" >> testconfig.sh
	done

	echo "TEST_PROVIDERS=sockets" >> testconfig.sh
	# enable ssh localhost without password
	pgrep -l sshd || die "ssh server do not run"

	log_cmd ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa

	log_cmd cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

	expect -c "set timeout -1;
        spawn ssh 127.0.0.1 exit;
        expect {
            *(yes/no)* {send -- yes\r;exp_continue;}
        }";

	if can_skip_sync_remote; then
		echo "skip make sync_remotes"
	else
		log_cmd make sync-remotes FORCE_SYNC_REMOTE=y USE_LLVM_LIBCPP=1 LIBCPP_INCDIR=/usr/local/libcxx/include/c++/v1 LIBCPP_LIBDIR=/usr/local/libcxx/lib || return
		can_skip_copy_source && {
			log_cmd rm $BENCHMARK_ROOT/$testcase/skip_sync_remote.* 2>/dev/null
			log_cmd touch $BENCHMARK_ROOT/$testcase/skip_sync_remote.$nvml_commit
		}
	fi

	return 0
}

check_ignore_single_case()
{
	local testcase=$1
	# nvml$ cat ignore_single_cases
	# # require tty
	# ex_libpmemobj/TEST15
	# ex_libpmemobj/TEST16
	# ex_libpmemobj_cpp/TEST1
	local pack_single_ignore="$BENCHMARK_ROOT/$casename/ignore_single_cases"

	[ -s "$pack_single_ignore" ] || return

	for s in $(cat $pack_single_ignore | grep -v '^#')
	do
		echo $s | grep -w -q "$testcase" &&
		echo "ignored_by_lkp $s" | tr / .
	done
}

run()
{
	local casename=$1
	local user_filter="$BENCHMARK_ROOT/$casename/user_filter"
	local testcase=

	log_cmd cd $BENCHMARK_ROOT/$casename/src/test

	# to fix SKIP: C++11 required
	log_cmd export CXX=g++

	# enable remote valgrind test
	echo "RPMEM_VALGRIND_ENABLED=y" >> testconfig.sh

	# to fix no point to a PMEM device
	echo "PMEM_FS_DIR_FORCE_PMEM=1" >> testconfig.sh

	for testcase in $testcases
	do
		# ignore some test cases
		local pack_ignore="$BENCHMARK_ROOT/$casename/ignore"

		[[ -s "$pack_ignore" ]] && grep -w -q "$testcase" "$pack_ignore" && echo "ignored_by_lkp $testcase" && continue

		check_ignore_single_case $testcase

		# export this env variable to enable obj_tx_a* tests
		[[ $testcase =~ obj_tx_a ]] && export MALLOC_MMAP_THRESHOLD_=0

		if [ "$LKP_LOCAL_RUN" != "1" ] && [[ -s "$user_filter" ]] && grep -w -q "$testcase" "$user_filter"; then
			log_cmd chown lkp:lkp -R $BENCHMARK_ROOT/$casename
			log_cmd chown lkp:lkp -R /tmp
			[ "$test" = "pmem" ] && log_cmd chown lkp:lkp -R /fs/pmem0
			log_cmd su lkp -c "./RUNTESTS -f $test $testcase  2>&1"
		else
			log_cmd ./RUNTESTS -f $test $testcase  2>&1
		fi  

		# unset env variable in case it do impact on other tests
		[[ $testcase =~ obj_tx_a ]] && unset MALLOC_MMAP_THRESHOLD_
	done

	return 0
}
