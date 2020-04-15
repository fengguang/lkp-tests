#!/bin/bash

. $LKP_SRC/lib/env.sh
. $LKP_SRC/lib/debug.sh

build_selftests()
{
	cd tools/testing/selftests	|| return

	# temporarily workaround compile error on gcc-6
	[[ "$LKP_LOCAL_RUN" = "1" ]] && {
		# local user may contain both gcc-5 and gcc-6
		CC=$(basename $(readlink $(which gcc)))
		# force to use gcc-5 to build x86
		[[ "$CC" = "gcc-6" ]] && command -v gcc-5 >/dev/null && sed -i -e '/^include ..\/lib.mk/a CC=gcc-5' x86/Makefile
	}

	make				|| return
	cd ../../..
}

prepare_test_env()
{
	# lkp qemu needs linux-selftests_dir and linux_headers_dir to reproduce kernel-selftests.
	# when reproduce bug reported by kernel test robot, the downloaded linux-selftests file is stored at /usr/src/linux-selftests
	linux_selftests_dir=(/usr/src/linux-selftests-*)
	linux_selftests_dir=$(realpath $linux_selftests_dir)
	if [[ $linux_selftests_dir ]]; then
		# when reproduce bug reported by kernel test robot, the downloaded linux-headers file is stored at /usr/src/linux-headers
		linux_headers_dirs=(/usr/src/linux-headers*)

		[[ $linux_headers_dirs ]] || die "failed to find linux-headers package"
		linux_headers_dir=${linux_headers_dirs[0]}
		echo "KERNEL SELFTESTS: linux_headers_dir is $linux_headers_dir"

		# headers_install's default location is usr/include which is required by several tests' Makefile
		mkdir -p "$linux_selftests_dir/usr/include" || die
		mount --bind $linux_headers_dir/include $linux_selftests_dir/usr/include || die
		mkdir -p "$linux_selftests_dir/tools/include/uapi/asm" || die
		mount --bind $linux_headers_dir/include/asm $linux_selftests_dir/tools/include/uapi/asm || die
	elif [ -d "/tmp/build-kernel-selftests/linux" ]; then
		# commit bb5ef9c change build directory to /tmp/build-$BM_NAME/xxx
		linux_selftests_dir="/tmp/build-kernel-selftests/linux"
		cd $linux_selftests_dir
		build_selftests
	else
		linux_selftests_dir="/lkp/benchmarks/kernel-selftests"
	fi
}

prepare_for_test()
{
	export PATH=/lkp/benchmarks/kernel-selftests/kernel-selftests/iproute2-next/sbin:$PATH
	# workaround hugetlbfstest.c open_file() error
	mkdir -p /hugepages

	# make sure the test_bpf.ko path for bpf test is right
	mkdir -p "$linux_selftests_dir/lib" || die
	if [[ "$LKP_LOCAL_RUN" = "1" ]]; then
		cp -r /lib/modules/`uname -r`/kernel/lib/* $linux_selftests_dir/lib
	else
		mount --bind /lib/modules/`uname -r`/kernel/lib $linux_selftests_dir/lib || die
	fi

	# temporarily workaround compile error on gcc-6
	command -v gcc-5 >/dev/null && log_cmd ln -sf /usr/bin/gcc-5 /usr/bin/gcc
	# fix cc: command not found
	command -v cc >/dev/null || log_cmd ln -sf /usr/bin/gcc /usr/bin/cc
	# fix bpf: /bin/sh: clang: command not found
	command -v clang >/dev/null || {
		installed_clang=$(find /usr/bin -name "clang-[0-9]*")
		log_cmd ln -sf $installed_clang /usr/bin/clang
	}
	# fix bpf: /bin/sh: line 2: llc: command not found
	command -v llc >/dev/null || {
		installed_llc=$(find /usr/bin -name "llc-*")
		log_cmd ln -sf $installed_llc /usr/bin/llc
	}
	# fix bpf /bin/sh: llvm-readelf: command not found
	command -v llvm-readelf >/dev/null || {
		llvm=$(find /usr/lib -name "llvm*" -type d)
		llvm_ver=${llvm##*/}
		export PATH=$PATH:/usr/lib/$llvm_ver/bin
	}
}

check_makefile()
{
	subtest=$1
	grep -E -q -m 1 "^TARGETS \+?=  ?$subtest" Makefile || {
		echo "${subtest} test: not in Makefile"
		return 1
	}
}

check_ignore_case()
{
	local casename=$1

	# the test of filesystems waits for the events from file, it will not never stop.
	[ $casename = "filesystems" ] && return

	# cgroup controllers can only be mounted in one hierarchy (v1 or v2).
	# If a controller mounted on a legacy v1, then it won't show up in cgroup2.
	# the v1 controllers are automatically mounted under /sys/fs/cgroup.
	# systemd automatically creates such mount points. mount_cgroup dosen't work.
	# not all controllers (like memory) become available even after unmounting all v1 cgroup filesystems.
	# To avoid this behavior, boot with the systemd.unified_cgroup_hierarchy=1.
	# then test cgroup could run, but the test will trigger out OOM (OOM is expected)
	# e.g test_memcg_oom_group_parent_events.
	# it disables swapping and tries to allocate anonymous memory up to OOM.
	# when the test triggers out OOM, lkp determines it as failure.
	[ $casename = "cgroup" ] && return

	# test tpm2 need hardware tpm
	ls "/dev/tpm*" 2>/dev/null || {
		[ $casename = "tpm2" ] && return
	}

	return 1
}

fixup_net()
{
	sed -i 's/l2tp.sh//' net/Makefile
	echo "ignored_by_lkp net.l2tp.sh test"
	# at v4.18-rc1, it introduces fib_tests.sh, which doesn't have execute permission
	# here is to fix the permission
	[[ -f $subtest/fib_tests.sh ]] && {
		[[ -x $subtest/fib_tests.sh ]] || chmod +x $subtest/fib_tests.sh
	}
	ulimit -l 10240
	modprobe fou
	modprobe nf_conntrack_broadcast
}

fixup_efivarfs()
{
	[[ -d "/sys/firmware/efi" ]] || {
		echo "ignored_by_lkp efivarfs test: /sys/firmware/efi dir does not exist"
		return 1
	}

	grep -q -F -w efivarfs /proc/filesystems || modprobe efivarfs || {
		echo "ignored_by_lkp efivarfs test: no efivarfs support, try enable CONFIG_EFIVAR_FS"
		return 1
	}
	# if efivarfs is built-in, "modprobe efivarfs" always returns 0, but it does not means
	# efivarfs is supported since this requires some specified hardwares, such as booting from
	# uefi, so check again
	log_cmd mount -t efivarfs efivarfs /sys/firmware/efi/efivars || {
		echo "ignored_by_lkp efivarfs test: unable to mount efivarfs to /sys/firmware/efi/efivars"
		return 1
	}
}

fixup_pstore()
{
	[[ -e /dev/pmsg0 ]] || {
		# in order to create a /dev/pmsg0, we insert a dummy ramoops device
		# Previously, the expected device(/dev/pmsg0) isn't created on skylake(Sandy Bridge is fine) when we specify ecc=1
		# So we chagne ecc=0 instead, that's good to both skylake and sand bridge.
		# NOTE: the root cause is not clear
		modprobe ramoops mem_address=0x8000000 ecc=0 mem_size=1000000 2>&1
		[[ -e /dev/pmsg0 ]] || {
			echo "ignored_by_lkp pstore test: /dev/pmsg0 does not exist"
			return 1
		}
	}
}

fixup_firmware()
{
	# As this case suggested, some distro(suse/debian) udev may have /lib/udev/rules.d/50-firmware.rules
	# which contains "SUBSYSTEM==firmware, ACTION==add, ATTR{loading}=-1", it will
	# immediately cancel all fallback requests, so here we remove it and restore after this case
	[ -e /lib/udev/rules.d/50-firmware.rules ] || return 0
	log_cmd mv /lib/udev/rules.d/50-firmware.rules . && {
		# udev have many rules located at /lib/udev/rules.d/, once those rules are changed
		# we need to restart udev service to reload the latest rules.
		if [[ -e /etc/init.d/udev ]]; then
			log_cmd /etc/init.d/udev restart
		else
			log_cmd systemctl restart systemd-udevd
		fi
	}
}

fixup_gpio()
{
	# gcc -O2 -g -std=gnu99 -Wall -I../../../../usr/include/    gpio-mockup-chardev.c ../../../gpio/gpio-utils.o ../../../../usr/include/linux/gpio.h  -lmount -I/usr/include/libmount -o gpio-mockup-chardev
	# gcc: error: ../../../gpio/gpio-utils.o: No such file or directory
	log_cmd make -C ../../../tools/gpio 2>&1 || return
}

cleanup_for_firmware()
{
	[[ -f 50-firmware.rules ]] && {
		log_cmd mv 50-firmware.rules /lib/udev/rules.d/50-firmware.rules
	}
}

subtest_in_skip_filter()
{
	local filter=$@
	echo "$filter" | grep -w -q "$subtest" && echo "ignored_by_lkp $subtest test"
}

fixup_memfd()
{
	# at v4.14-rc1, it introduces run_tests.sh, which doesn't have execute permission
	# here is to fix the permission
	[[ -f $subtest/run_tests.sh ]] && {
		[[ -x $subtest/run_tests.sh ]] || chmod +x $subtest/run_tests.sh
	}
	# before v4.13-rc1, we need to compile fuse_mnt first
	# check whether there is target "fuse_mnt" at Makefile
	grep -wq '^fuse_mnt:' $subtest/Makefile || return 0
	make fuse_mnt -C $subtest
}

fixup_bpf()
{
	log_cmd make -C ../../../tools/bpf/bpftool 2>&1 || return
	log_cmd make install -C ../../../tools/bpf/bpftool 2>&1 || return
	type ping6 && {
		sed -i 's/if ping -6/if ping6/g' bpf/test_skb_cgroup_id.sh 2>/dev/null
		sed -i 's/ping -${1}/ping${1%4}/g' bpf/test_sock_addr.sh 2>/dev/null
	}
	## ths test needs special device /dev/lircN
	sed -i 's/test_lirc_mode2_user//' bpf/Makefile
	echo "ignored_by_lkp bpf.test_lirc_mode2_user test"
	## test_tc_tunnel runs well but hang on perl process
	sed -i 's/test_tc_tunnel.sh//' bpf/Makefile
	echo "ignored_by_lkp bpf.test_tc_tunnel.sh test"
	sed -i 's/test_lwt_seg6local.sh//' bpf/Makefile
	echo "ignored_by_lkp bpf.test_lwt_seg6local.sh test"
	# some sh scripts actually need bash
	# ./test_libbpf.sh: 9: ./test_libbpf.sh: 0: not found
	[ "$(cmd_path bash)" = '/bin/bash' ] && [ $(readlink -e /bin/sh) != '/bin/bash' ] &&
		ln -fs bash /bin/sh

	local python_version=$(python3 --version)
	[[ "$python_version" =~ "3.5" ]] && sed -i "s/res)/res.decode('utf-8'))/" bpf/test_bpftool.py
}

prepare_for_selftest()
{
	if [ "$group" = "kselftests-00" ]; then
		# bpf is slow
		selftest_mfs=$(ls -d [a-b]*/Makefile | grep -v bpf)
	elif [ "$group" = "kselftests-01" ]; then
		# subtest lib cause kselftest incomplete run, it's a kernel issue
		# report [LKP] [software node] 7589238a8c: BUG:kernel_NULL_pointer_dereference,address
		selftest_mfs=$(ls -d [c-l]*/Makefile | grep -v -e livepatch -e lib)
	elif [ "$group" = "kselftests-02" ]; then
		# m* is slow
		selftest_mfs=$(ls -d [m-s]*/Makefile | grep -v -e rseq -e resctrl)
	elif [ "$group" = "kselftests-03" ]; then
		selftest_mfs=$(ls -d [t-z]*/Makefile | grep -v x86)
	elif [ "$group" = "kselftests-rseq" ]; then
		selftest_mfs=$(ls -d rseq/Makefile)
	elif [ "$group" = "kselftests-livepatch" ]; then
		selftest_mfs=$(ls -d livepatch/Makefile)
	elif [ "$group" = "kselftests-bpf" ]; then
		selftest_mfs=$(ls -d bpf/Makefile)
	elif [ "$group" = "kselftests-x86" ]; then
		selftest_mfs=$(ls -d x86/Makefile)
	elif [ "$group" = "kselftests-resctrl" ]; then
		selftest_mfs=$(ls -d resctrl/Makefile)
	elif [ "$group" = "kselftests-mptcp" ]; then
		selftest_mfs=$(ls -d net/mptcp/Makefile)
	elif [ "$group" = "kselftests-lib" ]; then
		selftest_mfs=$(ls -d lib/Makefile)
	fi
}

fixup_vm()
{
	# has too many errors now
	sed -i 's/hugetlbfstest//' vm/Makefile

	sed -i 's/.\/va_128TBswitch/echo [ignored_by_lkp] #.\/va_128TBswitch/' vm/run_vmtests
	sed -i 's/.\/mlock2-tests/echo [ignored_by_lkp] #.\/mlock2-tests/' vm/run_vmtests

	# we need to adjust two value in vm/run_vmtests accroding to the nr_cpu
	# 1) needmem=262144, in Byte
	# 2) ./userfaultfd hugetlb *128* 32, we call it memory here, in MB
	# For 1) it indicates the memory size we need to reserve for 2), it should be 2 * memory
	# For 2) looking to the userfaultfd.c, we found that it requires the second (128 in above) parameter (memory) to meet
	# memory >= huge_pagesize * nr_cpus, more details you can refer to userfaultfd.c
	# in 0Day, huge_pagesize is 2M by default
	# currently, test case have a fixed memory=128, so if testbox nr_cpu > 64, this case will fail.
	# for example:
	# 64 < nr_cpu <= 128, memory=128*2, needmem=memory*2
	# 128 < nr_cpu < (128 + 64), memory=128*3, needmem=memory*2
	[ $nr_cpu -gt 64 ] && {
		local memory=$((nr_cpu/64+1))
		memory=$((memory*128))
		sed -i "s#./userfaultfd hugetlb 128 32#./userfaultfd hugetlb $memory 32#" vm/run_vmtests
		memory=$((memory*1024*2))
		sed -i "s#needmem=262144#needmem=$memory#" vm/run_vmtests
	}

	sed -i 's/.\/compaction_test/echo [ignored_by_lkp] #.\/compaction_test/' vm/run_vmtests
}

platform_is_skylake_or_snb()
{
	# FIXME: Model number: snb: 42, ivb: 58, haswell: 60, skl: [85, 94]
	local model=$(lscpu | grep 'Model:' | awk '{print $2}')
	[[ -z "$model" ]] && die "FIXME: unknown platform cpu model number"
	([[ $model -ge 85 ]] && [[ $model -le 94 ]]) || [[ $model -eq 42 ]]
}

fixup_breakpoints()
{
	platform_is_skylake_or_snb && grep -qw step_after_suspend_test breakpoints/Makefile && {
		sed -i 's/step_after_suspend_test//' breakpoints/Makefile
		echo "ignored_by_lkp breakpoints.step_after_suspend_test test"
	}
}

fixup_x86()
{
	is_virt && grep -qw mov_ss_trap x86/Makefile && {
		sed -i 's/mov_ss_trap//' x86/Makefile
		echo "ignored_by_lkp x86.mov_ss_trap test"
	}
}

fixup_livepatch()
{
	# livepatch check if dmesg meet expected exactly, so disable redirect stdout&stderr to kmsg
	[[ -s "/tmp/pid-tail-global" ]] && cat /tmp/pid-tail-global | xargs kill -9 && echo "" >/tmp/pid-tail-global
}

build_tools()
{

	make allyesconfig		|| return
	make prepare			|| return
	# install cpupower command
	cd tools/power/cpupower		|| return
	make 				|| return
	make install			|| return
	cd ../../..
}

install_selftests()
{
	local header_dir="/tmp/linux-headers"

	mkdir -p $header_dir
	make headers_install INSTALL_HDR_PATH=$header_dir

	mkdir -p $BM_ROOT/usr/include
	cp -af $header_dir/include/* $BM_ROOT/usr/include

	mkdir -p $BM_ROOT/tools/include/uapi/asm
	cp -af $header_dir/include/asm/* $BM_ROOT/tools/include/uapi/asm

	mkdir -p $BM_ROOT/tools/testing/selftests
	cp -af tools/testing/selftests/* $BM_ROOT/tools/testing/selftests
}

pack_selftests()
{
	{
		echo /usr
		echo /usr/lib
		find /usr/lib/libcpupower.*
		echo /usr/bin
		echo /usr/bin/cpupower
		echo /lkp
		echo /lkp/benchmarks
		echo /lkp/benchmarks/$BM_NAME
		find /lkp/benchmarks/$BM_NAME/*
	} |
	cpio --quiet -o -H newc | gzip -n -9 > /lkp/benchmarks/${BM_NAME}.cgz
	[[ $arch ]] && mv "/lkp/benchmarks/${BM_NAME}.cgz" "/lkp/benchmarks/${BM_NAME}-${arch}.cgz"
}

run_tests()
{
	# zram: skip zram since 0day-kernel-tests always disable CONFIG_ZRAM which is required by zram
	# for local user, you can enable CONFIG_ZRAM by yourself
	# media_tests: requires special peripheral and it can not be run with "make run_tests"
	# watchdog: requires special peripheral
	# 1. requires /dev/watchdog device, but not all tbox have this device
	# 2. /dev/watchdog: need support open/ioctl etc file ops, but not all watchdog support it
	# 3. this test will not complete until issue Ctrl+C to abort it
	skip_filter="powerpc zram media_tests watchdog"

	local selftest_mfs=$@

	# kselftest introduced runner.sh since kernel commit 42d46e57ec97 "selftests: Extract single-test shell logic from lib.mk"
	[[ -e kselftest/runner.sh ]] && log_cmd sed -i 's/default_timeout=45/default_timeout=300/' kselftest/runner.sh
	for mf in $selftest_mfs; do
		subtest=${mf%/Makefile}

		check_ignore_case $subtest && echo "ignored_by_lkp $subtest test" && continue
		subtest_in_skip_filter "$skip_filter" && continue

		check_makefile $subtest || log_cmd make TARGETS=$subtest 2>&1

		if [[ "$subtest" = "breakpoints" ]]; then
			fixup_breakpoints
		elif [[ $subtest = "bpf" ]]; then
			fixup_bpf || die "fixup_bpf failed"
		elif [[ $subtest = "efivarfs" ]]; then
			fixup_efivarfs || continue
		elif [[ $subtest = "gpio" ]]; then
			fixup_gpio || continue
		elif [[ "$subtest" = "pstore" ]]; then
			fixup_pstore || continue
		elif [[ "$subtest" = "firmware" ]]; then
			fixup_firmware || continue
		elif [[ "$subtest" = "net" ]]; then
			fixup_net || continue
		elif [[ "$subtest" = "sysctl" ]]; then
			lsmod | grep -q test_sysctl || modprobe test_sysctl
		elif [[ "$subtest" = "ir" ]]; then
			## Ignore RCMM infrared remote controls related tests.
			sed -i 's/{ RC_PROTO_RCMM/\/\/{ RC_PROTO_RCMM/g' ir/ir_loopback.c
			echo "ignored_by_lkp ir.ir_loopback_rcmm tests"
		elif [[ "$subtest" = "memfd" ]]; then
			fixup_memfd
		elif [[ "$subtest" = "vm" ]]; then
			fixup_vm
		elif [[ "$subtest" = "x86" ]]; then
			fixup_x86
		elif [[ "$subtest" = "resctrl" ]]; then
			log_cmd resctrl/resctrl_tests 2>&1
			continue
		elif [[ "$subtest" = "livepatch" ]]; then
			fixup_livepatch
		fi

		log_cmd make run_tests -C $subtest  2>&1 || return

		if [[ "$subtest" = "firmware" ]]; then
			cleanup_for_firmware
		fi
	done
}
