#!/bin/bash

. $LKP_SRC/lib/env.sh
. $LKP_SRC/lib/debug.sh


# greater than or equal
libc_version_ge()
{
	local version=$1
	# debian: /lib/x86_64-linux-gnu/libc.so.6
	# /lib/x86_64-linux-gnu/libc.so.6
	# GNU C Library (Ubuntu GLIBC 2.27-3ubuntu1.4) stable release version 2.27.
	# printf '2.4.5\n2.8\n2.4.5.1\n' | sort -V
	[[ -f /lib/x86_64-linux-gnu/libc.so.6 ]] && libc_bin=/lib/x86_64-linux-gnu/libc.so.6

	# fedora: /usr/lib/libc.so.6
	# [root@iaas-rpma proc]# /usr/lib/libc.so.6
	# GNU C Library (GNU libc) stable release version 2.32.
	[[ -f /usr/lib/libc.so.6 ]] && libc_bin=/usr/lib/libc.so.6
	[[ "$libc_bin" ]] || return 0

	local local_version=$($libc_bin | head -1 | awk '{print $NF}')
	local_version=${local_version::-1} # omit the last .
	local greatest=$(printf "$local_version\n$1" | sort -V | head -1)

	[[ "$greatest" = "$version" ]]
}


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

# don't auto-reboot when panic
prepare_for_lkdtm()
{
	echo 0 >/proc/sys/kernel/panic_on_oops
	echo 1800 >/proc/sys/kernel/panic
}

prepare_test_env()
{
	has_cmd make || return

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
		mkdir -p "$linux_selftests_dir/usr/include" || return
		mount --bind $linux_headers_dir/include $linux_selftests_dir/usr/include || return

		mkdir -p "$linux_selftests_dir/tools/include/uapi/asm" || return
		mount --bind $linux_headers_dir/include/asm $linux_selftests_dir/tools/include/uapi/asm || return
	elif [ -d "/tmp/build-kernel-selftests/linux" ]; then
		# commit bb5ef9c change build directory to /tmp/build-$BM_NAME/xxx
		linux_selftests_dir="/tmp/build-kernel-selftests/linux"

		cd $linux_selftests_dir || return
		build_selftests
	else
		linux_selftests_dir="/lkp/benchmarks/kernel-selftests"
	fi
}

prepare_for_bpf()
{
	local modules_dir="/lib/modules/$(uname -r)"
	mkdir -p "$linux_selftests_dir/lib" || die
	if [[ "$LKP_LOCAL_RUN" = "1" ]]; then
		cp -r $modules_dir/kernel/lib/* $linux_selftests_dir/lib
	else
		# make sure the test_bpf.ko path for bpf test is right
		log_cmd mount --bind $modules_dir/kernel/lib $linux_selftests_dir/lib || die

		# required by build bpf_testmod.ko
		linux_headers_mod_dirs=(/usr/src/linux-headers*-bpf)
		linux_headers_mod_dirs=$(realpath $linux_headers_mod_dirs)
		[[ "$linux_headers_mod_dirs" ]] && export KDIR=$linux_headers_mod_dirs
	fi
}

prepare_for_test()
{
	export PATH=/lkp/benchmarks/kernel-selftests/kernel-selftests/iproute2-next/sbin:$PATH
	export PATH=$BENCHMARK_ROOT/kernel-selftests/kernel-selftests/dropwatch/bin:$PATH
	# workaround hugetlbfstest.c open_file() error
	mkdir -p /hugepages

	[[ "$group" = "bpf" || "$group" = "net" ]] && prepare_for_bpf
	[[ "$group" = "lkdtm" ]] && prepare_for_lkdtm

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

# Get testing env kernel config file
# Depending on your system, you'll find it in any one of these:
# /proc/config.gz
# /boot/config
# /boot/config-$(uname -r)
get_kconfig()
{
	local config_file="$1"
	if [[ -e "/proc/config.gz" ]]; then
		gzip -dc "/proc/config.gz" > "$config_file"
	elif [[ -e "/boot/config-$(uname -r)" ]]; then
		cat "/boot/config-$(uname -r)" > "$config_file"
	elif [[ -e "/boot/config" ]]; then
		cat "/boot/config" > "$config_file"
	else
		echo "Failed to get current kernel config"
		return 1
	fi

	[[ -s "$config_file" ]]
}

check_kconfig()
{
	local dependent_config=$1
	local kernel_config=$2

	while read line
	do
		# Avoid commentary on config
		[[ "$line" =~ "^CONFIG_" ]] || continue

		# CONFIG_BPF_LSM may casuse kernel panic, disable it by default
		# Failed to allocate manager object: No data available
		# [!!!!!!] Failed to allocate manager object, freezing.
		# Freezing execution.
		[[ "$line" =~ "CONFIG_BPF_LSM" ]] && continue

		# only kernel <= v5.0 has CONFIG_NFT_CHAIN_NAT_IPV4 and CONFIG_NFT_CHAIN_NAT_IPV6
		[[ "$line" =~ "CONFIG_NFT_CHAIN_NAT_IPV" ]] && continue

		# Some kconfigs are required as m, but they may set as y alreadly.
		# So don't check y/m, just match kconfig name
		# E.g. convert CONFIG_TEST_VMALLOC=m to CONFIG_TEST_VMALLOC=
		line="${line%=*}="
		if [[ "$line" = "CONFIG_DEBUG_PI_LIST=" ]]; then
			grep -q $line $kernel_config || {
				line="CONFIG_DEBUG_PLIST="
				grep -q $line $kernel_config || {
					echo "LKP WARN miss config $line of $dependent_config"
				}
			}
		else
			grep -q $line $kernel_config || {
				echo "LKP WARN miss config $line of $dependent_config"
			}
		fi
	done < $dependent_config
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

fixup_dma()
{
	# need to bind a device to dma_map_benchmark driver
	# for PCI devices
	local name=$(ls /sys/bus/pci/devices/ | head -1)
	[[ $name ]] || return
	echo dma_map_benchmark > /sys/bus/pci/devices/$name/driver_override || return
	local old_bind_dir=$(ls -d /sys/bus/pci/drivers/*/$name)
	[[ $old_bind_dir ]] && {
		echo $name > $(dirname $old_bind_dir)/unbind || return
	}
	echo $name > /sys/bus/pci/drivers/dma_map_benchmark/bind || return
}

skip_specific_net_cases()
{
	[ "$test" ] && return # test will be run standalone

	# skip specific cases from net group
	local skip_from_net="l2tp.sh tls fcnal-test.sh fib_nexthops.sh"
	for i in $(echo $skip_from_net)
	do
		sed -i "s/$i//" net/Makefile
		echo "LKP SKIP net.$i"
	done
}

fixup_net()
{
	# udpgro tests need enable bpf firstly
	# Missing xdp_dummy helper. Build bpf selftest first
	log_cmd make -C bpf 2>&1

	skip_specific_net_cases

	# at v4.18-rc1, it introduces fib_tests.sh, which doesn't have execute permission
	# here is to fix the permission
	[[ -f $subtest/fib_tests.sh ]] && {
		[[ -x $subtest/fib_tests.sh ]] || chmod +x $subtest/fib_tests.sh
	}
	ulimit -l 10240
	modprobe fou
	modprobe nf_conntrack_broadcast

	log_cmd make -C ../../../tools/testing/selftests/net 2>&1 || return
	log_cmd make install INSTALL_PATH=/usr/bin/ -C ../../../tools/testing/selftests/net 2>&1 || return
}

fixup_efivarfs()
{
	[[ -d "/sys/firmware/efi" ]] || {
		echo "LKP SKIP efivarfs | no /sys/firmware/efi"
		return 1
	}

	grep -q -F -w efivarfs /proc/filesystems || modprobe efivarfs || {
		echo "LKP SKIP efivarfs"
		return 1
	}
	# if efivarfs is built-in, "modprobe efivarfs" always returns 0, but it does not means
	# efivarfs is supported since this requires some specified hardwares, such as booting from
	# uefi, so check again
	log_cmd mount -t efivarfs efivarfs /sys/firmware/efi/efivars || {
		echo "LKP SKIP efivarfs"
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
			echo "LKP SKIP pstore | no /dev/pmsg0"
			return 1
		}
	}
}

fixup_ftrace()
{
	# FIX: sh: echo: I/O error
	sed -i 's/bin\/sh/bin\/bash/' ftrace/ftracetest

	# Stop tracing while reading the trace file by default
	# inspired by https://lkml.org/lkml/2021/10/26/1195
	echo 1 > /sys/kernel/debug/tracing/options/pause-on-trace
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
	export CFLAGS="-I../../../../usr/include"
}

fixup_proc()
{
	# proc-fsconfig-hidepid.c:25:17: error: ‘__NR_fsopen’ undeclared (first use in this function); did you mean ‘fsopen’?
	export CFLAGS="-I../../../../usr/include"
}

fixup_move_mount_set_group()
{
	libc_version_ge 2.32 && return

	# libc version lower than libc-2.32 do not define SYS_move_mount.
	# move_mount_set_group_test.c:221:16: error: ‘SYS_move_mount’ undeclared (first use in this function); did you mean ‘SYS_mount’?
	export CFLAGS="-DSYS_move_mount=__NR_move_mount"
	sed -ie "s/CFLAGS = /CFLAGS += /g" move_mount_set_group/Makefile
}

fixup_landlock()
{
	libc_version_ge 2.32 && return

	# libc version lower than libc-2.32 do not define SYS_move_mount.
	# fs_test.c:1304:23: error: 'SYS_move_mount' undeclared (first use in this function); did you mean 'SYS_mount'?
	export CFLAGS="-DSYS_move_mount=__NR_move_mount"
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
	echo "$filter" | grep -w -q "$subtest" && echo "LKP SKIP $subtest"
}

fixup_memfd()
{
	# at v4.14-rc1, it introduces run_tests.sh, which doesn't have execute permission
	# here is to fix the permission
	[[ -f $subtest/run_tests.sh ]] && {
		[[ -x $subtest/run_tests.sh ]] || chmod +x $subtest/run_tests.sh
	}

	# memfd_test.c:783:27: error: 'F_SEAL_FUTURE_WRITE' undeclared (first use in this function); did you mean 'F_SEAL_WRITE'?
	#  mfd_assert_add_seals(fd, F_SEAL_FUTURE_WRITE);
	# git diff
	# diff --git a/tools/testing/selftests/memfd/memfd_test.c b/tools/testing/selftests/memfd/memfd_test.c
	# index 74baab83fec3..71275b722832 100644
	# --- a/tools/testing/selftests/memfd/memfd_test.c
	# +++ b/tools/testing/selftests/memfd/memfd_test.c
	# @@ -20,6 +20,10 @@
	# #include <unistd.h>
	#  
	# #include "common.h"
	# +#ifndef F_SEAL_FUTURE_WRITE
	# +#define F_SEAL_FUTURE_WRITE 0x0010
	# +#endif
	libc_version_ge 2.32 || {
		sed -i '/^#include "common.h"/a #ifndef F_SEAL_FUTURE_WRITE\n#define F_SEAL_FUTURE_WRITE 0x0010\n#endif\n' $subtest/memfd_test.c
		# fuse_test.c:63:8: error: unknown type name '__u64'
		sed -i '/^#include "common.h"/a typedef unsigned long long __u64;' $subtest/fuse_test.c
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
	echo "LKP SKIP bpf.test_lirc_mode2_user"

	## test_tc_tunnel runs well but hang on perl process
	sed -i 's/test_tc_tunnel.sh//' bpf/Makefile
	echo "LKP SKIP bpf.test_tc_tunnel.sh"

	sed -i 's/test_lwt_seg6local.sh//' bpf/Makefile
	echo "LKP SKIP bpf.test_lwt_seg6local.sh"

	# some sh scripts actually need bash
	# ./test_libbpf.sh: 9: ./test_libbpf.sh: 0: not found
	[ "$(cmd_path bash)" = '/bin/bash' ] && [ $(readlink -e /bin/sh) != '/bin/bash' ] &&
		ln -fs bash /bin/sh

	local python_version=$(python3 --version)
	if [[ "$python_version" =~ "3.5" ]] && [[ -e "bpf/test_bpftool.py" ]]; then
		sed -i "s/res)/res.decode('utf-8'))/" bpf/test_bpftool.py
	fi
	if [[ -e kselftest/runner.sh ]]; then
		sed -i "48aCMD='./\$BASENAME_TEST'" kselftest/runner.sh
		sed -i "49aecho \$BASENAME_TEST | grep test_progs && CMD='./\$BASENAME_TEST -b mmap'" kselftest/runner.sh
		sed -i "s/tap_timeout .\/\$BASENAME_TEST/eval \$CMD/" kselftest/runner.sh
	fi
	# tools/testing/selftests/bpf/tools/sbin/bpftool
	export PATH=$linux_selftests_dir/tools/testing/selftests/bpf/tools/sbin:$PATH
}

fixup_kmod()
{
	# kmod tests failed on vm due to the following issue.
	# request_module: modprobe fs-xfs cannot be processed, kmod busy with 50 threads for more than 5 seconds now
	# MODPROBE_LIMIT decides threads num, reduce it to 10.
	sed -i 's/MODPROBE_LIMIT=50/MODPROBE_LIMIT=10/' kmod/kmod.sh

	# Although we reduce MODPROBE_LIMIT, but kmod_test_0009 sometimes timeout.
	# Reduce the number of times we run 0009.
	sed -i 's/0009\:150\:1/0009\:50\:1/' kmod/kmod.sh
}

prepare_for_selftest()
{
	if [ "$group" = "group-00" ]; then
		# bpf is slow
		selftest_mfs=$(ls -d [a-b]*/Makefile | grep -v ^bpf)
	elif [ "$group" = "group-01" ]; then
		# subtest lib cause kselftest incomplete run, it's a kernel issue
		# report [LKP] [software node] 7589238a8c: BUG:kernel_NULL_pointer_dereference,address
		# lkdtm is unstable [validated 1] f825d3f7ed
		selftest_mfs=$(ls -d [c-l]*/Makefile | grep -v -e ^ftrace -e ^livepatch -e ^lib -e ^cpufreq -e ^kvm -e ^firmware -e ^lkdtm)
	elif [ "$group" = "group-02" ]; then
		# m* is slow
		# pidfd caused soft_timeout in kernel-selftests.splice.short_splice_read.sh.fail.v5.9-v5.10-rc1.2020-11-06.132952
		selftest_mfs=$(ls -d [m-r]*/Makefile | grep -v -e ^rseq -e ^resctrl -e ^net -e ^netfilter -e ^rcutorture -e ^pidfd -e ^memory-hotplug)
	elif [ "$group" = "group-03" ]; then
		selftest_mfs=$(ls -d [t-z]*/Makefile | grep -v -e ^x86 -e ^tc-testing -e ^vm)
	elif [ "$group" = "mptcp" ]; then
		selftest_mfs=$(ls -d net/mptcp/Makefile)
	elif [ "$group" = "group-s" ]; then
		selftest_mfs=$(ls -d s*/Makefile | grep -v sgx)
	elif [ "$group" = "memory-hotplug" ]; then
		selftest_mfs=$(ls -d memory-hotplug/Makefile)
	else
		# bpf cpufreq firmware kvm lib livepatch lkdtm net netfilter pidfd rcutorture resctrl rseq tc-testing vm x86
		selftest_mfs=$(ls -d $group/Makefile)
	fi
}

fixup_vm()
{
	# has too many errors now
	sed -i 's/hugetlbfstest//' vm/Makefile

	local run_vmtests="run_vmtests.sh"
	[[ -f vm/run_vmtests ]] && run_vmtests="run_vmtests"
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
		sed -i "s#./userfaultfd hugetlb 128 32#./userfaultfd hugetlb $memory 32#" vm/$run_vmtests
		memory=$((memory*1024*2))
		sed -i "s#needmem=262144#needmem=$memory#" vm/$run_vmtests
	}

	sed -i 's/.\/compaction_test/echo -n LKP SKIP #.\/compaction_test/' vm/$run_vmtests
	# ./userfaultfd anon 128 32
	sed -i 's/.\/userfaultfd anon .*$/echo -n LKP SKIP #.\/userfaultfd/' vm/$run_vmtests

	# /usr/include/bits/mman-linux.h:# define MADV_PAGEOUT     21/* Reclaim these pages.  */
	# it doesn't exist in a old glibc<=2.28
	grep -qw MADV_PAGEOUT /usr/include/x86_64-linux-gnu/bits/mman-linux.h 2>/dev/null || {
		export EXTRA_CFLAGS="-DMADV_PAGEOUT=21"
	}

	# vmalloc stress prepare
	if [[ $test = "vmalloc-stress" ]]; then
		# iterations or nr_threads if not set, use default value
		[[ -z $iterations ]] && iterations=20
		[[ -z $nr_threads ]] && nr_threads="\$NUM_CPUS"
		[[ $iterations -le 0 || ($nr_threads != "\$NUM_CPUS" && $nr_threads -le 0) ]] && die "Paramters: iterations or nr_threads must > 0"
		sed -i 's/^STRESS_PARAM="nr_threads=$NUM_CPUS test_repeat_count=20"/STRESS_PARAM="nr_threads='$nr_threads' test_repeat_count='$iterations'"/' vm/test_vmalloc.sh
	fi
}

platform_is_skylake_or_snb()
{
	# FIXME: Model number: snb: 42, ivb: 58, haswell: 60, skl: [85, 94]
	local model=$(lscpu | grep 'Model:' | awk '{print $2}')
	[[ -z "$model" ]] && die "FIXME: unknown platform cpu model number"
	([[ $model -ge 85 ]] && [[ $model -le 94 ]]) || [[ $model -eq 42 ]]
}

cleanup_openat2()
{
	cd "$original_dir" || return
	umount /mnt/selftests || return
	rm -rf /mnt/selftests
}

fixup_openat2()
{
	original_dir=$(pwd)
	# The default filesystem of testing workdir is none, some flags is not supported
	# Create a virtual disk and format it with ext4 to run openat2
	dd if=/dev/zero of=/tmp/raw.img bs=1M count=100 || return
	mkfs -t ext4 /tmp/raw.img || return
	mkdir -p /mnt/selftests || return
	mount -t ext4 /tmp/raw.img /mnt/selftests || return
	cp -af ./* /mnt/selftests || return
	cd /mnt/selftests
}

fixup_breakpoints()
{
	platform_is_skylake_or_snb && grep -qw step_after_suspend_test breakpoints/Makefile && {
		sed -i 's/step_after_suspend_test//' breakpoints/Makefile
		echo "LKP SKIP breakpoints.step_after_suspend_test"
	}
}

fixup_x86()
{
	is_virt && grep -qw mov_ss_trap x86/Makefile && {
		sed -i 's/mov_ss_trap//' x86/Makefile
		echo "LKP SKIP x86.mov_ss_trap"
	}

	# List cpus that supported SGX
	# https://ark.intel.com/content/www/us/en/ark/search/featurefilter.html?productType=873&2_SoftwareGuardExtensions=Yes%20with%20Intel%C2%AE%20ME&1_Filter-UseConditions=3906
	# If cpu support SGX, also need open SGX in bios
	grep -qw sgx x86/Makefile && {
		grep -qw sgx /proc/cpuinfo || echo "Current host doesn't support sgx"
	}

	# Fix error /usr/bin/ld: /tmp/lkp/cc6bx6aX.o: relocation R_X86_64_32S against `.text' can not be used when making a shared object; recompile with -fPIC
	# https://www.spinics.net/lists/stable/msg229853.html
	grep -qw '\-no\-pie' x86/Makefile || sed -i '/^CFLAGS/ s/$/ -no-pie/' x86/Makefile
}

fixup_ptp()
{
	[[ -e "/dev/ptp0" ]] || {
		echo "LKP SKIP ptp.testptp"
		return 1
	}
}

fixup_livepatch()
{
	# livepatch check if dmesg meet expected exactly, so disable redirect stdout&stderr to kmsg
	[[ -s "/tmp/pid-tail-global" ]] && cat /tmp/pid-tail-global | xargs kill -9 && echo "" >/tmp/pid-tail-global
}

fixup_mount_setattr()
{
	# fix no real run for mount_setattr
	grep -q TEST_PROGS mount_setattr/Makefile ||
	grep "TEST_GEN_FILES +=" mount_setattr/Makefile | sed 's/TEST_GEN_FILES/TEST_PROGS/' >> mount_setattr/Makefile
}

fixup_tc_testing()
{
	# Suggested by the author
	# upstream commit: https://git.kernel.org/netdev/net/c/bdf1565fe03d
	sed -i 's/"matchPattern": "qdisc pfifo_fast 0: parent 1:\[1-9,a-f\].*/"matchPattern": "qdisc [a-zA-Z0-9_]+ 0: parent 1:[1-9,a-f][0-9,a-f]{0,2}",/g' tc-testing/tc-tests/qdiscs/mq.json
	sed -i 's/"matchPattern": "qdisc pfifo_fast 0: parent 1:\[1-4\].*/"matchPattern": "qdisc [a-zA-Z0-9_]+ 0: parent 1:[1-4]",/g' tc-testing/tc-tests/qdiscs/mq.json

	# As description of tdc_config.py, we can replace our own tc and ip
	# $ grep sbin/tc -B1 tdc_config.py
	#  # Substitute your own tc path here
	#  'TC': '/sbin/tc',
	if [ -e /lkp/benchmarks/kernel-selftests/kernel-selftests/iproute2-next/sbin/tc ]; then
		sed -i s,/sbin/tc,/lkp/benchmarks/kernel-selftests/kernel-selftests/iproute2-next/sbin/tc,g tc-testing/tdc_config.py
		sed -i s,/sbin/ip,/lkp/benchmarks/kernel-selftests/kernel-selftests/iproute2-next/sbin/ip,g tc-testing/tdc_config.py
	fi
	modprobe netdevsim
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

fixup_subtest()
{
	local subtest=$1
	if [[ "$subtest" = "breakpoints" ]]; then
		fixup_breakpoints
	elif [[ $subtest = "bpf" ]]; then
		fixup_bpf || die "fixup_bpf failed"
	elif [[ $subtest = "dma" ]]; then
		fixup_dma || die "fixup_dma failed"
	elif [[ $subtest = "efivarfs" ]]; then
		fixup_efivarfs || return
	elif [[ $subtest = "exec" ]]; then
		log_cmd touch ./$subtest/pipe || die "touch pipe failed"
	elif [[ $subtest = "gpio" ]]; then
		fixup_gpio || return
	elif [[ $subtest = "proc" ]]; then
		fixup_proc || return
	elif [[ $subtest = "move_mount_set_group" ]]; then
		fixup_move_mount_set_group || return
	elif [[ $subtest = "landlock" ]]; then
		fixup_landlock || return
	elif [[ $subtest = "openat2" ]]; then
		fixup_openat2 || return
	elif [[ "$subtest" = "pstore" ]]; then
		fixup_pstore || return
	elif [[ "$subtest" = "firmware" ]]; then
		fixup_firmware || return
	elif [[ "$subtest" = "net" ]]; then
		fixup_net || return
	elif [[ "$subtest" = "sysctl" ]]; then
		lsmod | grep -q test_sysctl || modprobe test_sysctl
	elif [[ "$subtest" = "ir" ]]; then
		## Ignore RCMM infrared remote controls related tests.
		sed -i 's/{ RC_PROTO_RCMM/\/\/{ RC_PROTO_RCMM/g' ir/ir_loopback.c
		echo "LKP SKIP ir.ir_loopback_rcmm"
	elif [[ "$subtest" = "memfd" ]]; then
		fixup_memfd
	elif [[ "$subtest" = "vm" ]]; then
		fixup_vm
	elif [[ "$subtest" = "x86" ]]; then
		fixup_x86
	elif [[ "$subtest" = "resctrl" ]]; then
		log_cmd resctrl/resctrl_tests 2>&1
		return 1
	elif [[ "$subtest" = "livepatch" ]]; then
		fixup_livepatch
	elif [[ "$subtest" = "ftrace" ]]; then
		fixup_ftrace
	elif [[ "$subtest" = "kmod" ]]; then
		fixup_kmod
	elif [[ "$subtest" = "ptp" ]]; then
		fixup_ptp || return
	elif [[ "$subtest" = "mount_setattr" ]]; then
		fixup_mount_setattr
	elif [[ "$subtest" = "tc-testing" ]]; then
		fixup_tc_testing # ignore return value so that doesn't abort the rest tests
	fi
	return 0
}

check_subtest()
{
	subtest_config="$subtest/config"
	kernel_config="/lkp/kernel-selftests-kernel-config"

	[[ -s "$subtest_config" ]] && get_kconfig "$kernel_config" && {
		check_kconfig "$subtest_config" "$kernel_config"
	}

	check_ignore_case $subtest && echo "LKP SKIP $subtest" && return 1

	# zram: skip zram since 0day-kernel-tests always disable CONFIG_ZRAM which is required by zram
	# for local user, you can enable CONFIG_ZRAM by yourself
	# media_tests: requires special peripheral and it can not be run with "make run_tests"
	# watchdog: requires special peripheral
	# 1. requires /dev/watchdog device, but not all tbox have this device
	# 2. /dev/watchdog: need support open/ioctl etc file ops, but not all watchdog support it
	# 3. this test will not complete until issue Ctrl+C to abort it
	# sched: https://www.spinics.net/lists/kernel/msg4062205.html
	skip_filter="arm64 sparc64 powerpc zram media_tests watchdog sched"
	subtest_in_skip_filter "$skip_filter" && return 1
	return 0
}

cleanup_subtest()
{
	if [[ "$subtest" = "firmware" ]]; then
		cleanup_for_firmware
	elif [[ "$subtest" = "openat2" ]]; then
		cleanup_openat2
	fi
}
