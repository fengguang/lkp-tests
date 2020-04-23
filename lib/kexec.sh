#!/bin/sh

# clear the initrds exported by last job
unset_last_initrd_vars()
{
	for last_initrd in $(env | grep "initrd=" | awk -F'=' '{print $1}')
	do
		unset $last_initrd
	done
}

read_kernel_cmdline_vars_from_append()
{
	unset_last_initrd_vars

	for i in $1
	do
		[ "$i" != "${i#job=}" ]			&& export "$i"
		[ "$i" != "${i#RESULT_ROOT=}" ]		&& export "$i"
		[ "$i" != "${i#initrd=}" ]		&& export "$i"
		[ "$i" != "${i#bm_initrd=}" ]		&& export "$i"
		[ "$i" != "${i#job_initrd=}" ]		&& export "$i"
		[ "$i" != "${i#lkp_initrd=}" ]		&& export "$i"
		[ "$i" != "${i#modules_initrd=}" ]	&& export "$i"
		[ "$i" != "${i#testing_nvdimm_modules_initrd=}" ]      && export "$i"
		[ "$i" != "${i#tbox_initrd=}" ]		&& export "$i"
		[ "$i" != "${i#linux_headers_initrd=}" ]	&& export "$i"
		[ "$i" != "${i#audio_sof_initrd=}" ]	&& export "$i"
		[ "$i" != "${i#syzkaller_initrd=}" ]	&& export "$i"
		[ "$i" != "${i#linux_selftests_initrd=}" ]	&& export "$i"
		[ "$i" != "${i#linux_perf_initrd=}" ]	&& export "$i"
		[ "$i" != "${i#ucode_initrd=}" ]   && export "$i"
	done
}

download_kernel()
{
	kernel="$(echo $kernel | sed 's/^\///')"

	echo "downloading kernel image ..."
	set_job_state "wget_kernel"
	kernel_file=$CACHE_DIR/$kernel
	http_get_newer "$kernel" $kernel_file || {
		set_job_state "wget_kernel_fail"
		echo "failed to download kernel: $kernel" 1>&2
		exit 1
	}
}

# if no rootfs_partition, mark it as modified
# FIXME: hard code isn't a good choice
is_local_cache()
{
	[ "$CACHE_DIR" = "/opt/rootfs/tmp" ]
}

initrd_is_modified()
{
	local file=$1
	local md5sumfile=$file.md5sum
	local new_md5sum

	is_local_cache || return 0

	new_md5sum="$(md5sum $file)"

	[ -f $md5sumfile ] || return 0
	[ -n "$new_md5sum" -a "$(cat $md5sumfile)" = "$new_md5sum" ] && {
		echo "$file isn't modified"
		return 1
	}

	return 0
}

initrd_is_correct()
{
	local file=$1

	initrd_is_modified $file || return 0
	gzip -dc $file | cpio -t >/dev/null
	ret=$?

	# update md5sum only when it's correct
	[ $ret -eq 0 ] && is_local_cache && md5sum $file >$file.md5sum

	return $ret
}

# for lkp qemu, it will set LKP_LOCAL_RUN=1
use_local_modules_initrds()
{
	[ "$LKP_LOCAL_RUN" = "1" ] && [ "$modules_initrd" ] && {
		# lkp qemu will create a link to modules.cgz under $CACHE_DIR
		# ls -al /root/.lkp/cache/modules.cgz
		# lrwxrwxrwx 1 root root 21 Jun 19 08:13 /root/.lkp/cache/modules.cgz -> /lkp-qemu/modules.cgz
		local local_modules=$CACHE_DIR/$(basename $modules_initrd)
		[ -e $local_modules ] || return
		echo "use local modules: $local_modules"
		unset modules_initrd
		local_modules_initrd=$local_modules
	}
}

download_initrd()
{
	local _initrd
	local initrds
	local local_modules_initrd

	echo "downloading initrds ..."
	set_job_state "wget_initrd"

	use_local_modules_initrds

	for _initrd in $(echo $initrd $tbox_initrd $job_initrd $lkp_initrd $bm_initrd $modules_initrd $testing_nvdimm_modules_initrd $linux_headers_initrd $audio_sof_initrd $syzkaller_initrd $linux_selftests_initrd $linux_perf_initrd $ucode_initrd | tr , ' ')
	do
		_initrd=$(echo $_initrd | sed 's/^\///')
		local file=$CACHE_DIR/$_initrd
		http_get_newer "$_initrd" $file || {
			rm -f $file
			set_job_state "wget_initrd_fail"
			echo Failed to download $_initrd
			exit 1
		}
		initrd_is_correct $file || {
			rm -f $file && echo "remove the the broken initrd: $file"
			set_job_state "initrd_broken"
			echo $_initrd is broken
			return 1
		}

		initrds="${initrds}$file "
	done

	# modules can not be the first, must be behind initrd
	initrds="${initrds} $local_modules_initrd"

	[ -n "$initrds" ] && {
		[ $# != 0 ] && initrds="${initrds}$*"

		concatenate_initrd="$CACHE_DIR/initrd-concatenated"
		initrd_option="--initrd=$concatenate_initrd"

		cat $initrds > $concatenate_initrd
	}
	return 0
}

kexec_to_next_job()
{
	local kernel append acpi_rsdp download_initrd_ret
	kernel=$(awk  '/^KERNEL / { print $2; exit }' $NEXT_JOB)
	append=$(grep -m1 '^APPEND ' $NEXT_JOB | sed 's/^APPEND //')
	rm -f /tmp/initrd-* /tmp/modules.cgz

	read_kernel_cmdline_vars_from_append "$append"
	append=$(echo "$append" | sed -r 's/ [a-z_]*initrd=[^ ]+//g')

	# Pass the RSDP address to the kernel for EFI system
	# Root System Description Pointer (RSDP) is a data structure used in the
	# ACPI programming interface. On systems using Extensible Firmware
	# Interface (EFI), attempting to boot a second kernel using kexec, an ACPI
	# BIOS Error (bug): A valid RSDP was not found (20160422/tbxfroot-243) was
	# logged.
	acpi_rsdp=$(grep -m1 ^ACPI /sys/firmware/efi/systab 2>/dev/null | cut -f2- -d=)
	[ -n "$acpi_rsdp" ] && append="$append acpi_rsdp=$acpi_rsdp"

	download_kernel
	download_initrd
	download_initrd_ret=$?

	jobfile_append_var "last_kernel=$(uname -r)"
	set_job_state "booting"

	echo "LKP: kexec loading..."
	echo kexec --noefi -l $kernel_file $initrd_option
	sleep 1 # kern  :warn  : [  +0.000073] sed: 34 output lines suppressed due to ratelimiting
	echo --append="${append}"
	sleep 1

	test -d 					"/$LKP_SERVER/$RESULT_ROOT/" &&
	dmesg --human --decode --color=always | gzip >	"/$LKP_SERVER/$RESULT_ROOT/pre-dmesg.gz" &&
	chown lkp.lkp					"/$LKP_SERVER/$RESULT_ROOT/pre-dmesg.gz" &&
	sync

	# store dmesg to disk and reboot
	[ $download_initrd_ret -ne 0 ] && sleep 119 && reboot

	kexec --noefi -l $kernel_file $initrd_option --append="$append"

	if [ -n "$(find /etc/rc6.d -name '[SK][0-9][0-9]kexec' 2>/dev/null)" ]; then
		# expecting the system to run "kexec -e" in some rc6.d/* script
		echo "LKP: rebooting"
		echo "LKP: rebooting" > /dev/ttyS0 &
		kexec -e 2>/dev/null
		sleep 100 || exit	# exit if reboot kills sleep as expected
	fi

	# run "kexec -e" manually. This is not a clean reboot and may lose data,
	# so run umount and sync first to reduce the risks.
	umount -a
	sync
	echo "LKP: kexecing"
	echo "LKP: kexecing" > /dev/ttyS0 &
	kexec -e 2>/dev/null

	set_job_state "kexec_fail"

	# in case kexec failed
	echo "LKP: rebooting after kexec"
	echo "LKP: rebooting after kexec" > /dev/ttyS0 &
	reboot 2>/dev/null
	sleep 244 || exit
	echo s > /proc/sysrq-trigger
	echo b > /proc/sysrq-trigger
}
