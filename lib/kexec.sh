#!/bin/sh

read_kernel_cmdline_vars_from_append()
{
	for i in $1
	do
		[ "$i" != "${i#job=}" ]			&& export "$i"
		[ "$i" != "${i#initrd=}" ]		&& export "$i"
		[ "$i" != "${i#bm_initrd=}" ]		&& export "$i"
		[ "$i" != "${i#job_initrd=}" ]		&& export "$i"
		[ "$i" != "${i#lkp_initrd=}" ]		&& export "$i"
		[ "$i" != "${i#modules_initrd=}" ]	&& export "$i"
		[ "$i" != "${i#tbox_initrd=}" ]		&& export "$i"
	done
}

download_kernel_initrd()
{
	local _initrd
	local initrds

	kernel=$(echo $kernel | sed 's/^\///')

	echo "downloading kernel image ..."
	set_job_state "wget_kernel"
	kernel_file=$CACHE_DIR/$kernel
	wget "http://$LKP_SERVER:$LKP_CGI_PORT/~$LKP_USER/$kernel" -nv -N -P $(dirname $kernel_file) || {
		echo "failed to download kernel: $kernel" 1>&2
		exit 1
	}

	echo "downloading initrds ..."
	set_job_state "wget_initrd"
	for _initrd in $(echo $initrd $tbox_initrd $job_initrd $lkp_initrd $bm_initrd $modules_initrd | tr , ' ')
	do
		_initrd=$(echo $_initrd | sed 's/^\///')
		local file=$CACHE_DIR/$_initrd
		wget -nv -N "http://$LKP_SERVER:$LKP_CGI_PORT/~$LKP_USER/$_initrd" -P $(dirname $file) || {
			echo Failed to download $_initrd
			exit 1
		}
		initrds="${initrds}$file "
	done

	[ -n "$initrds" ] && {
		concatenate_initrd="/tmp/initrd-$$"
		if [ $# == 0 ]; then
			cat $initrds > $concatenate_initrd
		else
			cat $initrds $* > $concatenate_initrd
		fi
		initrd_option="--initrd=$concatenate_initrd"
	}
	return 0
}

kexec_to_next_job()
{
	local kernel=$(awk  '/^KERNEL / { print $2; exit }' $NEXT_JOB)
	append=$(grep -m1 '^APPEND ' $NEXT_JOB | sed 's/^APPEND //')
	rm -f /tmp/initrd-* /tmp/modules.cgz

	read_kernel_cmdline_vars_from_append "$append"
	append=$(echo "$append" | sed -r 's/ [a-z_]*initrd=[^ ]+//g')

	download_kernel_initrd

	set_job_state "booting"

	echo "LKP: kexec loading..."
	echo kexec -l $kernel_file $initrd_option --append=\"$append\"
	kexec -l $kernel_file $initrd_option --append="$append"

	if [ -n "$(find /etc/rc6.d -name '[SK][0-9][0-9]kexec' 2>/dev/null)" ]; then
		# expecting the system to run "kexec -e" in some rc6.d/* script
		echo "LKP: rebooting"
		echo "LKP: rebooting" > /dev/ttyS0 &
		reboot 2>/dev/null
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
}
