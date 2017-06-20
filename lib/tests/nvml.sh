#!/bin/bash

check_param()
{
	local casename=$1

	log_cmd cd $BENCHMARK_ROOT/$casename/src/test || die "Can not find $casename/src/test dir"

	if [[ "$test" = "non-pmem" ]]; then
		local tmp_dir=$(mktemp -d)
		echo "NON_PMEM_FS_DIR=$tmp_dir" > testconfig.sh
	elif [[ "$test" = "pmem" ]]; then
		echo "PMEM_FS_DIR=/fs/pmem0" > testconfig.sh
	elif [[ "$test" = "none" ]]; then
		:
	else
		die "Parameter \"test\" is wrong"
	fi

	[[ -n "$group" ]] || die "Parameter \"group\" is empty"

	testcases=$(ls -d "$group"_* 2>/dev/null)

	[[ -n "$testcases" ]] || testcases=$(ls -d "$group" 2>/dev/null)
	[[ -n "$testcases" ]] || die "Parameter \"group\" is invalid"
}

build_env()
{
	local casename=$1

	log_cmd cd $BENCHMARK_ROOT/$casename

	log_cmd export CC=clang
	log_cmd export CXX=clang++

	# All C++ container tests need customized version of libc --libc++ to compile. So specify the path of libc++ to make.
	log_cmd make EXTRA_CFLAGS=-DUSE_VALGRIND USE_LLVM_LIBCPP=1 LIBCPP_INCDIR=/usr/local/libcxx/include/c++/v1/ LIBCPP_LIBDIR=/usr/local/libcxx/lib || return
	log_cmd make EXTRA_CFLAGS=-DUSE_VALGRIND USE_LLVM_LIBCPP=1 LIBCPP_INCDIR=/usr/local/libcxx/include/c++/v1/ LIBCPP_LIBDIR=/usr/local/libcxx/lib test || return
}

enable_remote_node()
{
	local casename=$1

	log_cmd cd $BENCHMARK_ROOT/$casename/src/test || die "Can not find $casename/src/test dir"

	# To fix no nodes provide. It takes another machines as remote nodes. We can use 
	# localhost as remote node but need to do some configs as below.
	for n in {0..3}
	do
		echo "NODE[$n]=127.0.0.1" >> testconfig.sh
		echo "NODE_WORKING_DIR[$n]=$BENCHMARK_ROOT/$casename/src/test" >> testconfig.sh
	done

	# enable ssh localhost without password
	pgrep -l sshd || die "ssh server do not run"

	log_cmd ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa

	log_cmd cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

	expect -c "set timeout -1;
        spawn ssh 127.0.0.1 exit;
        expect {
            *(yes/no)* {send -- yes\r;exp_continue;}
        }";
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

		# fix working dir not found
		# for remote case(remote_basic for example), more details please refer to the test scripts
		# 1. ssh into remote host
		# 2. enter into NODE_WORKING_DIR[$n]/test_$testcase
		# 3. ./$testcase <=== this binary usually stored at directory $testcase
		# 4. execute ../ctrld binary
		# so here we create a link to $testcase and ctrld
		echo $testcase | grep -q remote && {
			[[ -e "test_$testcase" ]] || {
				log_cmd ln -sf $testcase test_$testcase || die "fail to ln -sf $testcase test_$testcase"
			}
			[[ -e "ctrld" ]] || {
				log_cmd ln -sf tools/ctrld/ctrld || die "fail to ln -sf tools/ctrld/ctrld"
			}
		}

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
