#!/bin/bash

split_syscalls()
{
	local cmdfile="runtest/syscalls"
	[ -f "$cmdfile" ] || return 0
	# syscalls_partN file exists, abort splitting
	[ -f "${cmdfile}_part1" ] && return 0

	i=1
	n=1
	cat $cmdfile | sed -e '/^$/ d' -e 's/^[ ,\t]*//' -e '/^#/ d' | while read line
	do
		if [ $n -gt 300 ];then
			i=$(($i+1))
			n=1
		fi
		echo "$line" >> "runtest/syscalls_part${i}"
		n=$(($n+1))
	done

	echo "Splitting syscalls to syscalls_part1, ..., syscalls_part$i"
}

rearrange_dio()
{
	[ -f "dio" ] || return

	sed -e "s/^#.*//g" dio | awk '{if (length !=0) print $0}' >> diocase || return
	sed -n "1,20p" diocase >> dio-00 || return
	sed -n "21,25p" diocase >> dio-01 || return
	sed -n "26,28p" diocase >> dio-02 || return
	sed -n "29,\$p" diocase >> dio-03 || return
	rm diocase || return
}

rearrange_case()
{
	cd ./runtest || return

	# re-arrange the case dio
	rearrange_dio || return

	# re-arrange the case fs_readonly
	[ -f "fs_readonly" ] || return
	split -d -l15 fs_readonly fs_readonly- || return

	# re-arrange the case fs
	sed -e "s/^#.*//g" fs | awk '{if (length !=0) print $0}' > fscase || return
	split -d -l20 fscase fs- || return

	# re-arrange the case crashme
	sed -e "s/^#.*//g" crashme | awk '{if (length !=0) print $0}' > crashmecase || return
	split -d -l2 crashmecase crashme- || return

	# re-arrange the case mm
	grep -e oom -e min_free_kbytes mm > mm-00 || return
	cat mm | grep -v oom | grep -v min_free_kbytes > mm-01 || return

	# re-arrange the case net_stress.appl
	grep "http4" net_stress.appl > net_stress.appl-00 || return
	grep "http6" net_stress.appl > net_stress.appl-01 || return
	grep "ftp4-download" net_stress.appl > net_stress.appl-02 || return
	grep "ftp6-download" net_stress.appl > net_stress.appl-03 || return
	cat net_stress.appl | grep -v "http[4|6]" | grep -v "ftp[4|6]-download" > net_stress.appl-04 || return

	cd ..
}

patch_source()
{
	local patch=$LKP_SRC/pack/ltp-addon/$1
	[ -f $patch ] || return 0
	patch -p1 < $patch
}

rebuild()
{
	[ -d "$1" ] || return
	local build_dir=$1
	local current_dir=$(pwd)

	cd $build_dir && {
		make clean || return
		make || return
		cd $current_dir
	}
}

build_ltp()
{
	patch_source ltp.patch || return
	patch_source v2-0001-shmctl-enable-subtest-SHM_LOCK-SHM_UNLOCK-only-if.patch || return
	# fix commond:ar01
	patch_source ar_fail.patch || return
	# fix hyperthreading:smt_smp_affinity
	patch_source smt_smp_affinity.patch || return

	split_syscalls
	rearrange_case || return
	make autotools
	./configure --prefix=$1
	make || return

	# fix rpc test cases, linking to libtirpc-dev will make the tests failed in debian
	sed -i "s/^LDLIBS/#LDLIBS/" testcases/network/rpc/rpc-tirpc/tests_pack/Makefile.inc || return
	rebuild testcases/network/rpc/rpc-tirpc/tests_pack/rpc_suite/rpc/rpc_createdestroy_svc_destroy || return
	rebuild testcases/network/rpc/rpc-tirpc/tests_pack/rpc_suite/rpc/rpc_createdestroy_svcfd_create || return
	rebuild testcases/network/rpc/rpc-tirpc/tests_pack/rpc_suite/rpc/rpc_regunreg_xprt_register || return
	rebuild testcases/network/rpc/rpc-tirpc/tests_pack/rpc_suite/rpc/rpc_regunreg_xprt_unregister
}

install_ltp()
{
	make install
	cp testcases/commands/tpm-tools/tpmtoken/tpmtoken_import/tpmtoken_import_openssl.cnf $1/testcases/bin/
	cp testcases/commands/tpm-tools/tpmtoken/tpmtoken_protect/tpmtoken_protect_data.txt  $1/testcases/bin/
	grep -v -w -f $LKP_SRC/pack/ltp-black-list \
	runtest/syscalls > $1/runtest/syscalls
}
