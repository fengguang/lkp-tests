#!/bin/bash

. $LKP_SRC/lib/debug.sh

prepare_for_test()
{
	# workaround hugetlbfstest.c open_file() error
	mkdir -p /hugepages

	# has too many errors now
	sed -i 's/hugetlbfstest//' vm/Makefile

	# make sure the test_bpf.ko path for bpf test is right
	mkdir -p "$linux_selftests_dir/lib" || die
	mount --bind /lib/modules/`uname -r`/kernel/lib $linux_selftests_dir/lib || die

	# temporarily workaround compile error on gcc-6
	command -v gcc-5 >/dev/null && log_cmd ln -sf /usr/bin/gcc-5 /usr/bin/gcc
	# fix cc: command not found
	command -v cc >/dev/null || log_cmd ln -sf /usr/bin/gcc /usr/bin/cc
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

	return 1
}

prepare_for_net()
{
	ulimit -l 10240
}

prepare_for_efivarfs()
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

prepare_for_pstore()
{
	[[ ! -e /dev/pmsg0 ]] && { 
		# in order to create a /dev/pmsg0, we insert a dummy ramoops device
		modprobe ramoops mem_address=0x8000000 ecc=1 mem_size=1000000 2>&1
		[[ ! -e /dev/pmsg0 ]] && {
			echo "ignored_by_lkp pstore test: /dev/pmsg0 does not exist"
			return 1
		}
	}
}

prepare_for_firmware()
{
	# As this case suggested, some distro(suse/debian) udev may have /lib/udev/rules.d/50-firmware.rules
	# which contains "SUBSYSTEM==firmware, ACTION==add, ATTR{loading}=-1", it will
	# immediately cancel all fallback requests, so here we remove it and restore after this case

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

cleanup_for_firmware()
{
	[[ -f 50-firmware.rules ]] && {
		log_cmd mv 50-firmware.rules /lib/udev/rules.d/50-firmware.rules
	}
}

prepare_for_capabilities()
{
	# workaround: skip capabilities if lkp user is not exist.
	grep -q ^lkp: /etc/passwd || {
		echo "ignored_by_lkp capabilities test: lkp user is not exist"
		return 1
	}
	# workaround: run capabilities under user lkp
	log_cmd chown lkp $subtest -R 2>&1
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

prepare_for_bpf()
{
	make -C ../../../tools/bpf || return
	make install -C ../../../tools/bpf || return
}
