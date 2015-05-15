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
	exec  > /tmp/stdout
	exec 2> /tmp/stderr

	ln -s /usr/bin/tail /bin/tail-to-console
	ln -s /usr/bin/tail /bin/tail-to-serial

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
	tail-to-console -f /tmp/stdout /tmp/stderr > /dev/console &

	# some machines do not have serial console, writing to /dev/ttyS0 may fail
	[ -c /dev/ttyS0 ] &&
	echo > /dev/ttyS0 2>/dev/null && {
		tail-to-serial -f /tmp/stdout /tmp/stderr > /dev/ttyS0 2>/dev/null &
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

mount_rootfs()
{
	[ -n "$rootfs_partition" ] || return
	mkdir -p /opt/rootfs
	mount $rootfs_partition /opt/rootfs && return
	mkfs.ext4 -q $rootfs_partition
	mount $rootfs_partition /opt/rootfs
}
