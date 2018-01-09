#!/bin/sh

. $LKP_SRC/lib/mount.sh
. $LKP_SRC/lib/http.sh
. $LKP_SRC/lib/env.sh

# borrowed from linux/tools/testing/selftests/rcutorture/doc/initrd.txt
# Author: Paul E. McKenney <paulmck@linux.vnet.ibm.com>
mount_dev()
{
	[ -d /dev/pts ] &&
	[ -c /dev/kmsg ] &&
	[ -c /dev/null ] &&
	[ -c /dev/ttyS0 ] &&
	[ -c /dev/console ] && return

	mkdir -p /dev &&
	mount -t devtmpfs -o mode=0755 udev /dev &&
	mkdir -p /dev/pts &&
	mount -t devpts -o noexec,nosuid,gid=5,mode=0620 devpts /dev/pts && return

	has_cmd mknod || return

	echo "W: devtmpfs not available, falling back to tmpfs for /dev"
	mount -t tmpfs -o mode=0755 udev /dev

	[ -e /dev/console ]	|| mknod -m 600 /dev/console c 5 1
	[ -e /dev/kmsg ]	|| mknod -m 644 /dev/kmsg c 1 11
	[ -e /dev/null ]	|| mknod -m 666 /dev/null c 1 3
}

mount_kernel_fs()
{
	[ -d /proc/1 ] ||
	mount -t proc -o noexec,nosuid,nodev proc /proc

	[ -d /sys/kernel ] ||
	mount -t sysfs -o noexec,nosuid,nodev sysfs /sys

	mount_dev
}

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

	zcat /proc/config.gz | grep -q -F -x -e 'CONFIG_E1000=y' -e 'CONFIG_E1000E=y' || return

	echo "!!! IP-Config: No eth0/1/.. under /sys/class/net/ !!!" >&2
}

setup_network()
{
	local net_devices=

	network_ok && return || { echo "LKP: waiting for network..."; sleep 2; }
	network_ok && return || sleep 5
	network_ok && return || sleep 10
	network_ok && return

	is_virt &&
	[ ! -e /usr/share/initramfs-tools/scripts/functions ] && {
		export NO_NETWORK=1
		return
	}

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
	if has_cmd getent; then
		getent passwd lkp >/dev/null && return
	else
		grep -q '^lkp:' /etc/passwd && return
	fi

	mkdir -p /home

	if has_cmd useradd; then
		groupadd --gid 1090 lkp
		useradd --uid 1090 --gid 1090 lkp
	elif has_cmd adduser; then
		# busybox applet
		# quiet this F_SETLK error in yocto tiny image:
		# adduser: warning: can't lock '/etc/passwd': Permission denied
		adduser -D -u 1090 lkp 2>/dev/null
	else
		echo 'lkp:x:1090:1090::/home/lkp:/bin/sh' >> /etc/passwd
		echo 'lkp:x:1090:' >> /etc/group
	fi
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

	if has_cmd hostname; then
		hostname $HOSTNAME
	else
		echo $HOSTNAME > /proc/sys/kernel/hostname
	fi
}

setup_hosts()
{
	# /etc/hosts may be shared when it's NFSROOT and there is no obvious
	# way to detect if rootfs is already RAM based. So unconditionally
	# symlink it to my own tmpfs copy.
	local tmpfs_hosts=/tmp/my_hosts

	if [ -f '/etc/hosts-orig' ]; then
		cp /etc/hosts-orig $tmpfs_hosts
	else
		cp /etc/hosts $tmpfs_hosts
	fi
	echo "127.0.0.1 $HOSTNAME.sh.intel.com  $HOSTNAME" >> $tmpfs_hosts
	ln -fs $tmpfs_hosts /etc/hosts
}

show_mac_addr()
{
	if has_cmd ip; then
		ip link | awk '/ether/ {print $2; exit}'
	else
		ifconfig 2>/dev/null | awk '/ether/ {print $2; exit}'
	fi
}

announce_bootup()
{
	local version="$(cat /proc/sys/kernel/version 2>/dev/null| cut -f1 -d' ' | cut -c2-)"
	local release="$(cat /proc/sys/kernel/osrelease 2>/dev/null)"
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
	has_cmd tail || return

	exec  > /tmp/stdout
	exec 2> /tmp/stderr

	local sed_u=
	sed -h 2>&1|grep -q -- -u && sed_u='-u'

	local stdbuf='stdbuf -o0 -e0'
	has_cmd stdbuf || stdbuf=

	if [ -n "$stdbuf$sed_u" ]; then
		# limit 300 characters is to fix the following errro info:
		# sed: couldn't write N items to stdout: Invalid argument
		tail -f /tmp/stdout | $stdbuf sed $sed_u -r 's/^(.{0,900}).*$/<5>\1/' > /dev/kmsg &
		echo $! >> /tmp/pid-tail-global
		tail -f /tmp/stderr | $stdbuf sed $sed_u -r 's/^(.{0,900}).*$/<3>\1/' > /dev/kmsg &
		echo $! >> /tmp/pid-tail-global
	else
		tail -f /tmp/stdout > /dev/kmsg 2>/dev/null &
		echo $! >> /tmp/pid-tail-global
		tail -f /tmp/stderr > /dev/kmsg 2>/dev/null &
		echo $! >> /tmp/pid-tail-global
	fi
}

install_deb()
{
	local files
	local filename
	local filter_info="dpkg: warning: files list file for package '.*' missing;"

	[ -d /opt/deb ] || return 0

	# round one, install all debs directly
	files="$(find /opt/deb -name '*.deb' -type f 2>/dev/null)"
	[ -n "$files" ] || return
	# pack-deps have packed all depencecy packages into /osimage/deps/xxx/benchmark.cgz,
	# but it does not update dpkg database which will make dpkg misunderstand we have not
	# solved the dependent relationship, so here we ignore the dependency errors
	echo "install debs round one: dpkg -i --force-confdef --force-depends $files"
	dpkg -i --force-confdef --force-depends $files 2>/tmp/dpkg_error && return
	grep -v "$filter_info" /tmp/dpkg_error

	# round two, install all debs one by one accroding to keep-deb which is in sequence
	# sort keep-deb.${benchmark} by time, handle the oldest keep-deb.${benchmark} first
	for keepfile in $(ls -rt /opt/deb/keep-deb*)
	do
		echo "handle $keepfile..."
		# due to gwak pkg including pre-dependency definition,
		# gawk dependent libreadline7 install first.
		# so we generated keep-deb file which contains installation sequence,
		# and line by line installation.
		while read -r filename
		do
			echo "install debs round two: dpkg -i --force-confdef --force-depends /opt/deb/$filename"
			dpkg -i --force-confdef --force-depends /opt/deb/$filename 2>/tmp/dpkg_error || {
				grep -v "$filter_info" /tmp/dpkg_error
				echo "error: dpkg -i /opt/deb/$filename failed." 1>&2
				return 1
			}
		done < $keepfile
	done
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
		ROOTFS_DIR=/opt/rootfs
		mkdir -p $ROOTFS_DIR
		mount $rootfs_partition $ROOTFS_DIR || {
			mkfs.btrfs -f $rootfs_partition
			mount $rootfs_partition $ROOTFS_DIR
		}
		mkdir -p $ROOTFS_DIR/tmp
		CACHE_DIR=$ROOTFS_DIR/tmp
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
	[ "${HOSTNAME#*lkp-bxt01}"      != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-cfl-s01}"    != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-denverton2}" != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-g5}"         != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-glk01}"      != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-glk02}"      != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-ivb-d02}"    != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-ivb-toshiba1}"       != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-kbl-lenovo1}"        != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-kblr01}"     != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-kbls01}"     != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-kbly01}"     != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-minnow01}"   != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-skl-d01}"    != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-sklu-lenovo1}"       != "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-skly01}"     != "$HOSTNAME" ] && return 0

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
	NEXT_JOB="/tmp/next-job-$LKP_USER"

	echo "getting new job..."
	local mac="$(show_mac_addr)"
	local last_kernel=
	[ -n "$job" ] && last_kernel="last_kernel=$(grep ^kernel: $job | cut -d \" -f 2)&"
	http_get_cgi "cgi-bin/gpxelinux.cgi?hostname=${HOSTNAME}&mac=$mac&${last_kernel}${manual_reboot}lkp_wtmp" \
		$NEXT_JOB || {
		echo "cannot get next job" 1>&2
		return 1
	}

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
	[ -n "$VM_VIRTFS" ] && return
	[ -n "$NO_NETWORK" ] && return
	[ -z "$LKP_SERVER" ] && return

	local append="$(grep -m1 '^APPEND ' $NEXT_JOB | sed 's/^APPEND //')"
	for i in $append
	do
		[ "$i" != "${i#remote_rootfs=}" ] && export "$i"
		[ "$i" != "${i#root=}" ] && export "$i"
	done

	if [ -n "$remote_rootfs" -a -n "$root" ]; then
		$LKP_DEBUG_PREFIX $LKP_SRC/bin/rsync-rootfs $remote_rootfs $root

		# reboot only if rsynced rootfs is incomplete
		# What we really need to avoid is INCOMPLETE rsync, which might lead
		# to unexpected consistency problems
		local rootfs_name=${remote_rootfs##*/}
		# To remove the version info from rootfs's name
		# eywa-x86_64-20160714-1 ==> eywa-x86_64
		rootfs_name=${rootfs_name%*-[0-9]*-[0-9]}
		[ -f "$ROOTFS_DIR/$rootfs_name/etc/rsync-rootfs-complete" ] || {
			echo "rsync rootfs incomplete: from $remote_rootfs to $root" >&2
			exit 1
		}
	fi
}

is_same_kernel_and_rootfs()
{
	local next_kernel=$(awk '/^kernel: /{print $2}' $job | tr -d '"')
	[ -n "$next_kernel" ] || {
		echo "ERROR: no kernel in the job file: $job"
		return 1
	}

	if [ "$kernel" = "$next_kernel" ]; then
		# check run_on_local_disk flag in current and next job files
		# if run_on_local_disk setting is different, reboot is required
		grep -q "^run_on_local_disk: [a-zA-Z0-9_]*" $job
		if [ $? -eq 0 ]; then
			[ -n "$run_on_local_disk" ] || return 1
		else
			[ -n "$run_on_local_disk" ] && return 1
		fi

		local next_rootfs=$(awk '/^rootfs: /{print $2}' $job)
		[ -n "$next_rootfs" ] || {
			echo "ERROR: no rootfs in the job file: $job"
			return 1
		}

		[ "$rootfs" = "$next_rootfs" ] && return 0
	fi

	return 1
}

is_same_testcase()
{
	local current_testcase=$testcase
	local next_testcase=$(awk '/^testcase: /{print $2}' $job | tr -d '"')

	[ "$current_testcase" = "$next_testcase" ]
}

is_same_bp_memmap()
{
	local next_bp_memmap=$(awk '/bp_memmap:/{print $2}' $job)
	# $ awk -F'memmap=' '{print $2}' /proc/cmdline | awk '{print $1}'
	# 32G!4G
	local current_memmap=$(awk -F'memmap=' '{print $2}' /proc/cmdline | awk '{print $1}')

	[ "$next_bp_memmap" = "$current_memmap" ]
}

setup_env()
{
	[ "$result_service" != "${result_service#9p/}" ] &&
	export VM_VIRTFS=1
}

# initiation at boot stage; should be invoked once for
# each fresh boot.
boot_init()
{
	setup_env

	mount_kernel_fs
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
