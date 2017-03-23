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

	log_cmd make EXTRA_CFLAGS=-DUSE_VALGRIND || return
	log_cmd make EXTRA_CFLAGS=-DUSE_VALGRIND test || return
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
		log_cmd mkdir -p "/remote/dir$n" || die "mkdir -p /remote/dir$n failed"
		echo "NODE_WORKING_DIR[$n]=/remote/dir$n" >> testconfig.sh
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
	local user_filter="blk_pool log_pool obj_pool pmempool_rm util_file_create util_file_open"

	log_cmd cd $BENCHMARK_ROOT/$casename/src/test

	# to fix SKIP: C++11 required
	log_cmd export CXX=g++

	# enable remote valgrind test
	echo "RPMEM_VALGRIND_ENABLED=y" >> testconfig.sh

	# to fix no point to a PMEM device
	echo "PMEM_FS_DIR_FORCE_PMEM=1" >> testconfig.sh

	while read testcase
	do
		# fix working dir not found
		for n in {0..3}
		do
			log_cmd mkdir -p "/remote/dir$n/test_$testcase" || die "mkdir -p /remote/dir$n/test_testcase failed"
		done

		if [ "$LKP_LOCAL_RUN" != "1" ] && echo "$user_filter" | grep -q -w "$testcase"; then
			log_cmd chown lkp:lkp -R $BENCHMARK_ROOT/$casename
			log_cmd chown lkp:lkp -R /tmp
			[ "$test" = "pmem" ] && log_cmd chown lkp:lkp -R /fs/pmem0
			log_cmd su lkp -c "./RUNTESTS $testcase  2>&1"
		else
			log_cmd ./RUNTESTS $testcase  2>&1
		fi  
	done <<< "$testcases"
}
