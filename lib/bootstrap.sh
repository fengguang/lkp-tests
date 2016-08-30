#!/bin/sh

. $LKP_SRC/lib/mount.sh
. $LKP_SRC/lib/http.sh
. $LKP_SRC/lib/env.sh

mount_tmpfs()
{
	# ubuntu etc/init/mounted-tmp.conf wrongly mounted /tmp:
	# mount -t tmpfs -o size=1048576,mode=1777 overflow /tmp
	# grep -q /tmp /proc/mounts && umount /tmp

	is_mount_point /tmp && return

	mount -t tmpfs -o mode=1777 tmp /tmp
}

network_ok()
{
	local i
	for i in /sys/class/net/*/
	do
		[ "${i#*/lo/}" != "$i" ] && continue
		[ "${i#*/eth}" != "$i" ] && net_devices="$net_devices $(basename $i)"
		[ "${i#*/en}"  != "$i" ] && net_devices="$net_devices $(basename $i)"
		[ "$(cat $i/operstate)" = 'up' ]		&& return 0
		[ "$(cat $i/carrier 2>/dev/null)" = '1' ]	&& return 0
	done
	return 1
}

# Many randconfig test kernels may not have the necessary NIC driver.
# Show warning only when the kernel does compile in suitable driver.
# QEMU VMs use e1000 or virtio; HW machines mostly have e1000 or igb.
# Let's catch and warn the common case.
warn_no_eth0()
{
	[ -f /proc/config.gz ] || return

	zgrep -q -F -x -e 'CONFIG_E1000=y' -e 'CONFIG_E1000E=y' /proc/config.gz || return

	echo "!!! IP-Config: No eth0/1/.. under /sys/class/net/ !!!" >&2
}

setup_network()
{
	local net_devices=

	network_ok && return || { echo "LKP: waiting for network..."; sleep 2; }
	network_ok && return || sleep 5
	network_ok && return || sleep 10
	network_ok && return

	if [ -z "$net_devices" ]; then

		warn_no_eth0

		echo \
		ls /sys/class/net
		ls /sys/class/net

		# VMs do many randconfig boot tests which can write the
		# valuable dmesg/kmsg to ttyS0/ttyS1
		if is_virt; then
			export NO_NETWORK=1
			return
		else
			reboot 2>/dev/null
			exit
		fi
	fi

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
	has_cmd groupadd || return
	has_cmd useradd || return
	has_cmd getent || return

	getent passwd lkp >/dev/null && return

	mkdir -p /home
	groupadd --gid 1090 lkp
	useradd --uid 1084 --gid 1090 lkp
}

run_ntpdate()
{
	[ -z "$NO_NETWORK" ] || return
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

show_mac_addr()
{
	if has_cmd ip; then
		ip link | awk '/ether/ {print $2; exit}'
	else
		arp -n  | awk '/ether/ {print $3; exit}'
	fi
}

announce_bootup()
{
	local version="$(cat /proc/sys/kernel/version | cut -f1 -d' ' | cut -c2-)"
	local release="$(cat /proc/sys/kernel/osrelease)"
	local mac="$(show_mac_addr)"

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
	[ -c /dev/kmsg ] || return
	has_cmd stdbuf || return
	has_cmd tail || return

	exec  > /tmp/stdout
	exec 2> /tmp/stderr

	# limit 200 characters is to fix the following errro info:
	# sed: couldn't write N items to stdout: Invalid argument
	tail -f /tmp/stdout | stdbuf -i0 -o0 sed -r 's/^(.{,300}).*$/<5>\1/'  > /dev/kmsg &
	tail -f /tmp/stderr | stdbuf -i0 -o0 sed -r 's/^(.{,300}).*$/<3>\1/'  > /dev/kmsg &
}

install_deb()
{
	local files

	files="$(ls /opt/deb 2>/dev/null)" || return
	[ -n "$files" ] || return

	dpkg -i $files || return
	rm $files
}

fixup_packages()
{
	install_deb

	has_cmd ldconfig &&
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

	# /lib64/ld-linux-x86-64.so.2 program interpreter
	[ -e /lib64/ld-linux-x86-64.so.2 ] || {
		[ -d /lib64 ] || mkdir /lib64
		ln -s /lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
	}
}

mount_debugfs()
{
	check_mount debug /sys/kernel/debug -t debugfs
}

# cache pkg for only one week to avoid "no space left" issue
cleanup_pkg_cache()
{
	local pkg_cache=$1
	local cleanup_stamp=$pkg_cache/cleanup_stamp/$(date +%U)
	[ -d "$cleanup_stamp" ] && return
	mkdir $cleanup_stamp -p

	find "$pkg_cache" \( -type f -mtime +7 -delete \) -or \( -type d -ctime +7 -empty -delete \)
}

mount_rootfs()
{
	if [ -n "$rootfs_partition" ]; then
		mkdir -p /opt/rootfs
		mount $rootfs_partition /opt/rootfs || {
			mkfs.btrfs -f $rootfs_partition
			mount $rootfs_partition /opt/rootfs
		}
		mkdir -p /opt/rootfs/tmp
		CACHE_DIR=/opt/rootfs/tmp
		cleanup_pkg_cache $CACHE_DIR/pkg
	else
		CACHE_DIR=/tmp/cache
		mkdir -p $CACHE_DIR
	fi

	export CACHE_DIR
}

show_default_gateway()
{
	if has_cmd ip; then
		ip -4 route list 0/0 | cut -f3 -d' '
	else
		route -n | awk '$4 == "UG" {print $2}'
	fi
}

netconsole_init()
{
	[ -z "$netconsole_port" ] && return
	[ -n "$NO_NETWORK" ] && return

	# use default gateway as netconsole server
	netconsole_server=$(show_default_gateway)
	[ -n "$netconsole_server" ] || return
	modprobe netconsole netconsole=@/,$netconsole_port@$netconsole_server/ 2>/dev/null
}

tbox_cant_kexec()
{
	is_virt && return 0

	# following tbox are buggy while using kexec to boot
	[ "${HOSTNAME#*lkp-g5}"		!= "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*minnow-max}"	!= "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-t410}"	!= "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-bdw01}"	!= "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-bdw02}"	!= "$HOSTNAME" ] && return 0

	[ -x '/sbin/kexec' ] || return 0

	return 1
}

download_job()
{
	job="$(grep -o 'job=[^ ]*.yaml' $NEXT_JOB | awk -F '=' '{print $2}')"
	local job_cgz=${job%.yaml}.cgz

	# TODO: escape is necessary. We might also need download some extra cgz
	http_get_file "$job_cgz" /tmp/next-job.cgz
	(cd /; gzip -dc /tmp/next-job.cgz | cpio -id)
}

__next_job()
{
	NEXT_JOB="$CACHE_DIR/next-job-$LKP_USER"

	echo "getting new job..."
	local mac="$(show_mac_addr)"
	local last_kernel=
	[ -n "$job" ] && last_kernel="last_kernel=$(grep ^kernel: $job | cut -d \" -f 2)&"
	http_get_file "cgi-bin/gpxelinux.cgi?hostname=${HOSTNAME}&mac=$mac&${last_kernel}${manual_reboot}lkp_wtmp" \
		$NEXT_JOB
	grep -q "^KERNEL " $NEXT_JOB || {
		echo "no KERNEL found" 1>&2
		cat $NEXT_JOB
		return 1
	}

	return 0
}

next_job()
{
	LKP_USER=${pxe_user:-lkp}

	__next_job || {
		local secs=300
		while true; do
			sleep $secs || exit # killed by reboot
			secs=$(( secs + 300 ))
			__next_job && break
		done
	}

	download_job
}

rsync_rootfs()
{
	[ -z "$NO_NETWORK" ] && return

	local append="$(grep -m1 '^APPEND ' $NEXT_JOB | sed 's/^APPEND //')"
	for i in $append
	do
		[ "$i" != "${i#remote_rootfs=}" ] && export "$i"
		[ "$i" != "${i#root=}" ] && export "$i"
	done

	[ -n "$remote_rootfs" -a -n "$root" ] &&
	$LKP_DEBUG_PREFIX $LKP_SRC/bin/rsync-rootfs $remote_rootfs $root
}

# initiation at boot stage; should be invoked once for
# each fresh boot.
boot_init()
{
	mount_tmpfs
	redirect_stdout_stderr

	setup_hostname
	setup_hosts

	announce_bootup

	add_lkp_user

	fixup_packages

	setup_network
	run_ntpdate

	mount_debugfs
	mount_rootfs

	netconsole_init
}
