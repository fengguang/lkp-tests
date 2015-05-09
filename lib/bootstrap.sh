#!/bin/sh

. $LKP_SRC/lib/mount.sh

mount_tmpfs()
{
	# ubuntu etc/init/mounted-tmp.conf wrongly mounted /tmp:
	# mount -t tmpfs -o size=1048576,mode=1777 overflow /tmp
	# grep -q /tmp /proc/mounts && umount /tmp

	mountpoint -q /tmp && return

	mount -t tmpfs -o mode=1777 tmp /tmp
}

network_ok()
{
	local i
	for i in /sys/class/net/*/
	do
		[ "${i#*/lo/}" != "$i" ] && continue
		[ "$(cat $i/operstate)" = 'up' ]		&& return 0
		[ "$(cat $i/carrier 2>/dev/null)" = '1' ]	&& return 0
	done
	return 1
}

setup_network()
{
	network_ok && return
	$LKP_DEBUG_PREFIX $LKP_SRC/bin/run-ipconfig
	network_ok && return

	local err_msg='IP-Config: Auto-configuration of network failed'
	dmesg | grep -q -F "$err_msg" || {
		# Include $err_msg in the error message so that it matches
		# /lkp/printk-error-messages
		# and be detected as a dmesg error. Add some prefix/sufix
		# to slightly distinguish it from kernel DHCP failure message.
		echo "!!! $err_msg !!!" >&2
		echo "!!! $err_msg !!!" > /dev/ttyS0
	}
	reboot 2>/dev/null
	exit
}

add_lkp_user()
{
	getent passwd lkp >/dev/null && return

	mkdir -p /home
	groupadd --gid 1090 lkp
	useradd --uid 1084 --gid 1090 lkp
}

run_ntpdate()
{
	[ "$LKP_SERVER" = inn ] || return
	[ -x '/usr/sbin/ntpdate' ] || return

	local hour="$(date +%H)"

	ntpdate -b $LKP_SERVER

	[ "$hour" != "$(date +%H)" ] && [ -x '/etc/init.d/hwclock.sh' ] && {
		# update hardware clock, to carry the adjusted time across reboots
		/etc/init.d/hwclock.sh restart 2> /dev/null
	}
}

setup_hostname()
{
	export HOSTNAME=${testbox:-localhost}

	echo $HOSTNAME > /tmp/hostname
	ln -fs /tmp/hostname /etc/hostname

	hostname $HOSTNAME
}

setup_hosts()
{
	if [ -f '/etc/hosts-orig' ]; then
		cp /etc/hosts-orig /tmp/hosts
	else
		cp /etc/hosts /tmp/hosts
	fi
	echo "127.0.0.1 $HOSTNAME.sh.intel.com  $HOSTNAME" >> /tmp/hosts
	ln -fs /tmp/hosts /etc/hosts
}

announce_bootup()
{
	local version="$(cat /proc/sys/kernel/version | cut -f1 -d' ' | cut -c2-)"
	local release="$(cat /proc/sys/kernel/osrelease)"
	local mac="$(ip link | awk '/ether/ {print $2; exit}')"

	echo 'Kernel tests: Boot OK!'

	# make sure to output something if serial console is not ttyS0
	# this helps diagnose serial console connections
	for ttys in ttyS0 ttyS1 ttyS2 ttyS3
	do
		echo "LKP: HOSTNAME $HOSTNAME, MAC $mac, kernel $release $version, serial console /dev/$ttys" > /dev/$ttys 2>/dev/null
	done
}

redirect_stdout_stderr()
{
	exec  > $TMP/stdout
	exec 2> $TMP/stderr

	ln -s /usr/bin/tail $LKP_SRC/bin/tail-to-console
	ln -s /usr/bin/tail $LKP_SRC/bin/tail-to-output
	ln -s /usr/bin/tail $LKP_SRC/bin/tail-to-serial

	# write log to screen as well so that we can see them
	# even network is broken

	for i in $(seq 10)
	do
		[ -c /dev/console ] &&
		[ -c /dev/ttyS0   ] && break
		sleep 1
	done

	# the test fixes "cannot create /dev/console: Input/output error"
	[ -c /dev/console ] &&
	tail-to-console -f $TMP/stdout $TMP/stderr > /dev/console &

	tail-to-output  -f $TMP/stdout $TMP/stderr > $TMP/output &

	# some machines do not have serial console, writing to /dev/ttyS0 may fail
	[ -c /dev/ttyS0 ] &&
	echo > /dev/ttyS0 2>/dev/null && {
		tail-to-serial -f $TMP/stdout $TMP/stderr > /dev/ttyS0 2>/dev/null &
	}
}

fixup_packages()
{
	ldconfig

	[ -x /usr/bin/gcc ] && [ ! -e /usr/bin/cc ] &&
	ln -sf gcc /usr/bin/cc

	# hpcc dependent library
	[ -e /usr/lib/atlas-base/atlas/libblas.so.3 ] && [ ! -e /usr/lib/libblas.so.3 ] &&
	ln -sf /usr/lib/atlas-base/atlas/libblas.so.3 /usr/lib/libblas.so.3

	local aclocal_bin
	for aclocal_bin in /usr/bin/aclocal-*
	do
		[ -x "$aclocal_bin" ] && [ ! -e /usr/bin/aclocal ] &&
		ln -sf $aclocal_bin /usr/bin/aclocal
	done
}

mount_debugfs()
{
	check_mount debug /sys/kernel/debug -t debugfs
}

mount_cgroup()
{
	[ -f "$CGROUP_MNT/tasks" ] && return
	awk 'NR > 1 {print "\\s\\+" $1 "\\."}' /proc/cgroups > $TMP/availble-cgroup_subsys
	cgroup_subsys=$(grep -o -f $TMP/availble-cgroup_subsys $job)
	[ -n "$cgroup_subsys" ] || return
	cgroup_subsys=$(echo $cgroup_subsys | sed -e 's/\. /,/g' -e 's/\.$//')
	cmd mkdir -p $CGROUP_MNT
	cmd mount -t cgroup -o $cgroup_subsys none $CGROUP_MNT
}

mount_rootfs()
{
	[ -n "$rootfs_partition" ] || return
	mkdir -p /opt/rootfs
	mount $rootfs_partition /opt/rootfs && return
	mkfs.ext4 -q $rootfs_partition
	mount $rootfs_partition /opt/rootfs
}

validate_result_root()
{
	[ -n "$RESULT_ROOT" ] || RESULT_ROOT=$result_root
	[ -n "$RESULT_ROOT" ] || {
		echo 'No RESULT_ROOT' >&2
		run_job_failed=1
		job_done_boot_next
	}
}

should_do_cifs()
{
	grep -q clear-linux-os /etc/os-release && return 0
	grep -q -w 'nfs' /proc/filesystems && return 1
	modprobe nfs 2>/dev/null
	grep -q -w 'nfs' /proc/filesystems && return 1
	return 0
}

mount_result_root()
{
	[ -n "$result_service" ] || {
		if should_do_cifs; then
			result_service=//$LKP_SERVER/result
		else
			result_service=$LKP_SERVER:/result
		fi
	}

	case $result_service in
		*:*)
			mount.nfs $result_service $RESULT_MNT || return
			result_fs=nfs
			;;
		//*/*)
			modprobe cifs 2>/dev/null
			mount.cifs -o guest $result_service $RESULT_MNT || return
			result_fs=cifs
			;;
		9p/*)
			mkdir -p -m 02775 $RESULT_ROOT
			export RESULT_MNT=$RESULT_ROOT
			export TMP_RESULT_ROOT=$RESULT_ROOT
			mkdir -p $TMP
			mount -t 9p -o trans=virtio $result_service $RESULT_MNT  -oversion=9p2000.L,posixacl,cache=loose
			result_fs=virtfs
			;;
		*)
			echo "unknown result_service $result_service" >&2
			return 1
			;;
	esac

	mountpoint -q $RESULT_MNT
}

setup_result_root()
{
	validate_result_root

	echo RESULT_ROOT=$RESULT_ROOT
	echo job=$job

	export TMP_RESULT_ROOT=$TMP/result
	mkdir -p $TMP_RESULT_ROOT

	RESULT_PREFIX=/$LKP_SERVER
	export RESULT_ROOT=$RESULT_PREFIX$RESULT_ROOT
	export RESULT_MNT=$RESULT_PREFIX/result

	mkdir -p $RESULT_MNT
	mount_result_root $RESULT_MNT || {
		if grep -q -w $result_fs /proc/filesystems; then
			set_job_state 'error_mount'
			sleep 300
		else
			set_job_state "miss_$result_fs"
		fi
		job_done_boot_next
	}

	local files="$(echo $RESULT_ROOT/*)"
	[ -e "${files%% *}" ] && echo "RESULT_ROOT not empty: $(ls -l $RESULT_ROOT)" >&2
}

record_dmesg()
{
	killall rsyslogd klogd 2>/dev/null || :
	dmesg > $RESULT_ROOT/dmesg
	ln -s $(command -v cat) $LKP_SRC/bin/cat-kmsg
	stdbuf -o0 -e0 cat-kmsg /proc/kmsg >> $RESULT_ROOT/dmesg &
	echo $! > $TMP/pid-dmesg
	[ -n "$BASH_VERSION" ] && disown # quiet the "Terminated" notification to stderr

	[ -n "$netconsole_port" ] && {
		# use default gateway as netconsole server
		netconsole_server=$(ip -4 route list 0/0 | cut -f3 -d' ')
		modprobe netconsole netconsole=@/,$netconsole_port@$netconsole_server/ 2>/dev/null
	}
}

# in case someone is logged in, give him at most 10hour time to do manual checks
wait_on_manual_check()
{
	# extra sleep for user login after a failed job,
	# if "wait_debug_on_fail" is defined in the job file
	[ "$run_job_failed" != 0 ] && [ -n "$wait_debug_on_fail" ] && {
		sleep $wait_debug_on_fail
	}

	for i in $(seq 600)
	do
		# t100 has XWindow auto login
		if [ "$HOSTNAME" = 't100' ]; then
			local users="$(users)"
			[ "${users#* }" != "$users" ] || break
		else
			[ -n "$(users)" ] || break
		fi
		disturbed=1
		[ "$i" = 1 ] && set_job_state 'manual_check'
		sleep 60
	done
	return $disturbed
}

tbox_cant_kexec()
{
	[ "$(virt-what)" = 'kvm' ] && return 0

	# following tbox are buggy while using kexec to boot
	[ "${HOSTNAME#*lkp-nex04}"	!= "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-t410}"	!= "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-bdw01}"	!= "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-bdw02}"	!= "$HOSTNAME" ] && return 0

	[ -x '/sbin/kexec' ] || return 0

	return 1
}

jobfile_append_var()
{
	local i
	for i
	do
		echo "$i" >> $job_script
	done
}

set_job_state()
{
	jobfile_append_var "job_state=$1"
}

job_done()
{
	:
}

boot_next()
{
	tbox_cant_kexec && {
		reboot 2>/dev/null
		exit
	}

	mount_rootfs

	local secs=300
	while true
	do
		$LKP_SRC/bin/kexec-lkp $pxe_user
		sleep $secs || exit # killed by reboot
		secs=$(( secs + 300 ))
	done
}

job_done_boot_next() {
	touch $TMP/job-finished
	wait_on_manual_check
	[ -n "$disturbed" ] || job_done
	boot_next
}
