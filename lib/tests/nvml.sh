#!/bin/bash

check_param()
{
	local casename=$1

	log_cmd cd $BENCHMARK_ROOT/$casename/src/test || die "Can not find $casename/src/test dir"

	if [[ "$test" = "non-pmem" ]] || [[ "$test" = "pmem" ]] || [[ "$test" = "none" ]]; then
		tmp_dir=$(mktemp -d)
		echo "NON_PMEM_FS_DIR=$tmp_dir" > testconfig.sh
		echo "PMEM_FS_DIR=/fs/pmem0" >> testconfig.sh
		echo "ENABLE_NFIT_TESTS=y" >> testconfig.sh
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

	# ./check_max_mmap.sh: line 44: /build/nvml/src/src/test/tools/anonymous_mmap/../../testconfig.sh: No such file or directory
	log_cmd cp src/test/testconfig.sh.example src/test/testconfig.sh
	# All C++ container tests need customized version of libc --libc++ to compile. So specify the path of libc++ to make.
	log_cmd make EXTRA_CFLAGS="-DPAGE_SIZE=4096 -DUSE_VALGRIND" USE_LLVM_LIBCPP=1 LIBCPP_INCDIR=/usr/local/libcxx/include/c++/v1/ LIBCPP_LIBDIR=/usr/local/libcxx/lib || return
	log_cmd make EXTRA_CFLAGS="-DPAGE_SIZE=4096 -DUSE_VALGRIND" USE_LLVM_LIBCPP=1 LIBCPP_INCDIR=/usr/local/libcxx/include/c++/v1/ LIBCPP_LIBDIR=/usr/local/libcxx/lib test || return
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

# make[1]: *** No rule to make target '../../../src/../src/debug/libpmem/memcpy_nt_avx512f_clflush.o', needed by 'pmem_has_auto_flush'. Stop.
fixup_sync_remote()
{
	local casename=$1
	log_cmd cd $BENCHMARK_ROOT/$casename/src || return
	log_cmd make EXTRA_CFLAGS=-DUSE_VALGRIND USE_LLVM_LIBCPP=1 LIBCPP_INCDIR=/usr/local/libcxx/include/c++/v1/ LIBCPP_LIBDIR=/usr/local/libcxx/lib -C libpmem DEBUG=1 || return
	log_cmd make EXTRA_CFLAGS=-DUSE_VALGRIND USE_LLVM_LIBCPP=1 LIBCPP_INCDIR=/usr/local/libcxx/include/c++/v1/ LIBCPP_LIBDIR=/usr/local/libcxx/lib -C libpmem DEBUG=0 || return
	log_cmd make EXTRA_CFLAGS=-DUSE_VALGRIND USE_LLVM_LIBCPP=1 LIBCPP_INCDIR=/usr/local/libcxx/include/c++/v1/ LIBCPP_LIBDIR=/usr/local/libcxx/lib -C common DEBUG=1 || return
	log_cmd make EXTRA_CFLAGS=-DUSE_VALGRIND USE_LLVM_LIBCPP=1 LIBCPP_INCDIR=/usr/local/libcxx/include/c++/v1/ LIBCPP_LIBDIR=/usr/local/libcxx/lib -C common DEBUG=0 || return
	log_cmd cd -
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
		fixup_sync_remote $casename || return
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

setup_mount_loop_dev()
{
	[[ -d "$tmp_dir" ]] || return
	truncate --size 200M /tmp/loop-file
	losetup loop0 /tmp/loop-file
	mkfs.ext4 /dev/loop0 &>/dev/null
	mount /dev/loop0 $tmp_dir
}

umount_loop_dev()
{
	[[ -d "$tmp_dir" ]] || return
	umount $tmp_dir
	losetup -d /dev/loop0
}

run()
{
	local casename=$1
	local user_filter="$BENCHMARK_ROOT/$casename/user_filter"
	local testcase=

	log_cmd cd $BENCHMARK_ROOT/$casename/src/test

	# to fix SKIP: C++11 required
	log_cmd export CXX=g++
	log_cmd ln -sf /usr/local/bin/ndctl /usr/bin/ndctl

	# enable remote valgrind test
	echo "RPMEM_VALGRIND_ENABLED=y" >> testconfig.sh

	# to fix no point to a PMEM device
	echo "PMEM_FS_DIR_FORCE_PMEM=1" >> testconfig.sh

	[ "$test" = "pmem" ] && echo "PMEM_FS_DIR_FORCE_PMEM=2" >> testconfig.sh
	for testcase in $testcases
	do
		# ignore some test cases
		local pack_ignore="$BENCHMARK_ROOT/$casename/ignore"

		[[ -s "$pack_ignore" ]] && grep -w -q "$testcase" "$pack_ignore" && echo "ignored_by_lkp $testcase" && continue

		check_ignore_single_case $testcase

		# fix util_extent/TEST0: SKIP file system tmpfs (ext4 required)
		[[ "$testcase" = "util_extent" ]] && [[ "$test" = "non-pmem" ]] && setup_mount_loop_dev

		# export this env variable to enable obj_tx_a* tests
		[[ $testcase =~ obj_tx_a ]] && export MALLOC_MMAP_THRESHOLD_=0

		if [ "$LKP_LOCAL_RUN" != "1" ] && [[ -s "$user_filter" ]] && grep -w -q "$testcase" "$user_filter"; then
			log_cmd chown lkp:lkp -R $BENCHMARK_ROOT/$casename
			log_cmd chown lkp:lkp -R /tmp
			log_cmd chown lkp:lkp -R /fs/pmem0
			log_cmd su lkp -c "./RUNTESTS -f $test $testcase  2>&1"
		else
			log_cmd ./RUNTESTS -f $test $testcase  2>&1
		fi  

		# unset env variable in case it do impact on other tests
		[[ $testcase =~ obj_tx_a ]] && unset MALLOC_MMAP_THRESHOLD_
		[[ "$testcase" = "util_extent" ]] && [[ "$test" = "non-pmem" ]] && umount_loop_dev
	done

	return 0
}

# Automatically generate ignore file to skip test cases which can not be enabled at present.
build_ignore_file()
{
	cd $source_dir || return
	git grep "require_node_libfabric" | awk -F '[:/]' '{if (!a[$3]++ && $3 != "unittest") {print $3} }' > ignore
	git grep "require_dax_devices" | awk -F '[:/]' '{if (!a[$3]++ && $3 != "unittest") {print $3} }' >> ignore
	echo "vmmalloc_fork" >> ignore
	echo "pmempool_check" >> ignore
	echo "obj_pmalloc_mt" >> ignore

	# ignore single case instead of the whole directory

	# nvml$ git grep "^require_tty" src/test
	# src/test/ex_libpmemobj/TEST15:require_tty
	# src/test/ex_libpmemobj/TEST16:require_tty
	# src/test/ex_libpmemobj_cpp/TEST1:require_tty
	single_cases=$(git grep "^require_tty" src/test | awk -F':' '{print $1}' | sed 's/src\/test\///')

	mkdir -p ignore_single_cases_dir

	# do backup, move the ignored binary file into ignore_single_cases_dir, and rename it like:
	# nvml$ ls ignore_signal_cases_dir
	# ex_libpmemobj_cpp_TEST1  ex_libpmemobj_TEST15  ex_libpmemobj_TEST16
	#
	# nvml$ echo $single_cases
	# ex_libpmemobj/TEST15 ex_libpmemobj/TEST16 ex_libpmemobj_cpp/TEST1
	for s in $single_cases
	do
		mv src/test/$s ignore_single_cases_dir/$(echo $s | tr / _)
	done

	echo "# require tty" >> ignore_single_cases
	echo "$single_cases" >> ignore_single_cases
}

# Automatically detect and generate new groups for each fs-types
build_generate_testgroup()
{
	cd $source_dir/src/test
	rm -f group_none group_non-pmem group_pmem group_by_fs_type.yaml

	# 1.find out the groups
	#   directoy obj_bucket, obj_list, blk_pool,blk_nblock will be treat as two
	#   groups named obj and blk that we can find at LKP_SRC/job/nvml.yaml
	# 2.find out the fs-type for each 2. find out the fs-type for each groupgroup
	#   travel $group/TESTx, it will match one of bellow rule
	#     a. keyword: require_fs_type none  -> put into fs_type none
	#     b. keyword: require_fs_type non-pmem -> put into fs_type non-pmem
	#     c. keyword: require_fs_type pmem -> put into fs_type pmem
	#     d. keyword: require_fs_type any -> put into fs_type both non-pmem and pmem
	#     e. no keyword 'require_fs_type' -> put into fs_type both non-pmem and pmem
	for nvml_case in `ls`
	do
		[ -f "$nvml_case/TEST0" ] || continue
		[ -x "$nvml_case/TEST0" ] || continue
		cd $nvml_case
		scripts=`ls -1 TEST* | grep -v -i -e "\.ps1" | sort -V`

		for run_script in $scripts
		do
			req_fs=`grep -w "require_fs_type" $run_script` || {
				echo  $nvml_case >> ../group_pmem
				echo  $nvml_case >> ../group_non-pmem
				continue
			}
			fs_type=`echo ${req_fs:15}`
			for type in $fs_type
			do
				case "$type"
				in
				any)
					echo $nvml_case >> ../group_pmem
					echo $nvml_case >> ../group_non-pmem
					;;
				non-pmem)
					echo $nvml_case >>../group_non-pmem
					;;
				pmem)
					echo $nvml_case >>../group_pmem
					;;
				none)
					echo $nvml_case >>../group_none
					;;
				esac
			done
		done
		cd - >/dev/null
	done
	for type in pmem non-pmem none
	do
	    echo "$type:" >> group_by_fs_type.yaml
	    awk -F '_' '{print $1}' group_$type | sort -u | sed 's/^/  - /g'>> group_by_fs_type.yaml
	done
	rm -f group_none group_non-pmem group_pmem
	return 0
}

# Auto generate user_filter to enable those tests which do not need run as superuser.
build_user_filter_file()
{
	cd $source_dir || return
	git grep "require_no_superuser" | awk -F '[:/]' '{if (!a[$3]++ && $3 != "unittest") {print $3} }' > user_filter
}
