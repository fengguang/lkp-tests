#!/bin/sh

. $LKP_SRC/lib/mount.sh
. $LKP_SRC/lib/http.sh
. $LKP_SRC/lib/env.sh
. $LKP_SRC/lib/reboot.sh
. $LKP_SRC/lib/ucode.sh
. $LKP_SRC/lib/tbox.sh
. $LKP_SRC/lib/detect-system.sh
. $LKP_SRC/lib/network.sh
. $LKP_SRC/lib/log.sh

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
	is_docker && return
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

resize_virtual_rootfs()
{
        # tmpfs and rootfs default use 50% memory:
        #
        #   root@taishan200-2280-2s48p-256g--a13 ~# mount | head -n 1
        #   rootfs on / type rootfs (rw,size=133395136k,nr_inodes=2084299)
        #
        #   root@taishan200-2280-2s48p-256g--a13 ~# df -h /
        #   Filesystem      Size  Used Avail Use% Mounted on
        #   rootfs          128G  114G   14G  90% /
        #
        # this maybe cause the docker no space error.

        if mount | head -n 1 | grep "type rootfs" > /dev/null
        then
                echo "Set the rootfs to 90% memory"
                mount -o remount,rw,size=90% rootfs /
        fi
	# Test Result: 
	#   root@taishan200-2280-2s64p-256g--a125 ~# free -g
	#                 total        used        free      shared  buff/cache   available
	#   Mem:          255Gi       8.5Gi       243Gi       2.7Gi       2.9Gi       224Gi
	#   Swap:            0B          0B          0B
	#   root@taishan200-2280-2s64p-256g--a125 ~# df -h /
	#   Filesystem      Size  Used Avail Use% Mounted on
	#   rootfs          230G  2.7G  228G   2% /

}

get_net_devices()
{
	local net_devices
	local i
	for i in /sys/class/net/*/
	do
		[ "${i#*/lo/}" != "$i" ] && continue
		[ "${i#*/eth}" != "$i" ] && net_devices="$net_devices $(basename $i)"
		[ "${i#*/en}"  != "$i" ] && net_devices="$net_devices $(basename $i)"
	done

	echo "$net_devices"
}

net_devices_link()
{
	local operation=$1
	local net_devices="$(get_net_devices)"
	local ndev
	for ndev in $net_devices
	do
		if has_cmd ip; then
			ip link set $ndev $operation
		elif has_cmd ifconfig; then
			ifconfig $ndev $operation
		fi
	done
}

test_ping()
{
	has_cmd ping || {
		echo "command not found: ping, skip ping test."
		return 0
	}
	ping -c 1 -w 1 $LKP_SERVER > /dev/null
}

network_ok()
{
	local i
	for i in /sys/class/net/*/
	do
		[ "${i#*/lo/}" != "$i" ] && continue
		[ "$(cat $i/operstate)" = 'up' ]		&& test_ping && return 0
		[ "$(cat $i/carrier 2>/dev/null)" = '1' ]	&& test_ping && return 0
	done

	return 1
}

network_up()
{
	net_devices_link up
	network_ok || { echo "LKP: waiting for network..."; sleep 10; }
	network_ok || sleep 20
	network_ok || sleep 30
	network_ok || return 1

	ip route | grep -q 'default via' || {
		# recover the default route
		[ -f /tmp/ip_route ] && ip route add $(grep 'default via' /tmp/ip_route)
		[ $? = 0 ] || {
			echo "failed to set default route"
			return $?
		}
	}

	set_tbox_wtmp 'network_up'
}

network_down()
{
	set_tbox_wtmp 'network_down'
	# backup route table
	ip route > /tmp/ip_route
	net_devices_link down
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
	network_ok && return || { echo "LKP: waiting for network..."; sleep 2; }
	network_ok && return || sleep 5
	network_ok && return || sleep 10
	network_ok && return

	is_virt &&
	[ ! -e /usr/share/initramfs-tools/scripts/functions ] && {
		export NO_NETWORK=1
		echo "export NO_NETWORK=1 due to no initramfs-tools"
		return
	}

	$LKP_DEBUG_PREFIX $LKP_SRC/bin/run-ipconfig
	network_ok && return

	local net_devices="$(get_net_devices)"
	if [ -z "$net_devices" ]; then

		warn_no_eth0

		echo \
		ls /sys/class/net
		ls /sys/class/net

		# VMs do many randconfig boot tests which can write the
		# valuable dmesg/kmsg to ttyS0/ttyS1
		if is_virt; then
			export NO_NETWORK=1
			echo "export NO_NETWORK=1 due to no net devices"
			return
		else
			reboot 2>/dev/null
			exit
		fi
	fi

	local err_msg='IP-Config: Auto-configuration of network failed'
	dmesg | grep -q -F "$err_msg" || {
		# Include $err_msg in the error message so that it matches
		# /lkp/lkp/printk-error-messages
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
	[ -n "$LKP_SERVER" ] || return

	has_cmd ntpdate || return

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
	is_docker && return

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
	is_docker && return

	suffix="sh.intel.com"
	[ -n "${lab}" ] && suffix="compass-ci.net"

	# /etc/hosts may be shared when it's NFSROOT and there is no obvious
	# way to detect if rootfs is already RAM based. So unconditionally
	# symlink it to my own tmpfs copy.
	local tmpfs_hosts=/tmp/my_hosts

	if [ -f '/etc/hosts-orig' ]; then
		cp /etc/hosts-orig $tmpfs_hosts
	else
		cp /etc/hosts $tmpfs_hosts
	fi
	echo "127.0.0.1 $HOSTNAME.${suffix}  $HOSTNAME" >> $tmpfs_hosts
	echo "::1 $HOSTNAME.${suffix}  $HOSTNAME" >> $tmpfs_hosts
	ln -fs $tmpfs_hosts /etc/hosts
}

setup_dns()
{
	[ -n "$DNS_HOST" ] || return 0

	echo "nameserver ${DNS_HOST}" > /etc/resolv.conf
}

export_ip_mac()
{
	if has_cmd ip; then
		export PUB_NIC=$(ip route get 1.2.3.4 | awk '{print $5; exit}')
		export PUB_IP=$(ip route get 1.2.3.4 | awk '{print $7; exit}')
	elif has_cmd route; then
		export PUB_NIC=$(route -n | awk '/[UG][UG]/ {print $8}')
		has_cmd ifconfig && export PUB_IP=$(ifconfig $PUB_NIC | awk '/inet / {print $2}')
	else
		export PUB_NIC=$(awk 'NR > 1 && $3 != "00000000" { print $1; exit }' /proc/net/route)
		has_cmd ifconfig && export PUB_IP=$(ifconfig $PUB_NIC | awk '/inet / {print $2}')
	fi

	export PUB_MAC=$(cat /sys/class/net/$PUB_NIC/address)
	[ -n "$SCHED_HOST" ] && PUB_MAC=$(echo "$PUB_MAC" | tr : -)
}

announce_bootup()
{
	local version="$(cat /proc/sys/kernel/version 2>/dev/null| cut -f1 -d' ' | cut -c2-)"
	local release="$(cat /proc/sys/kernel/osrelease 2>/dev/null)"

	# make sure to output something if serial console is not ttyS0
	# this helps diagnose serial console connections
	for ttys in ttyS0 ttyS1 ttyS2 ttyS3
	do
		echo "LKP: HOSTNAME $HOSTNAME, MAC $PUB_MAC, IP $PUB_IP, kernel $release $version, serial console /dev/$ttys" > /dev/$ttys 2>/dev/null
	done
}

redirect_stdout_stderr()
{
	has_cmd tail || return

	if is_docker; then
		[ -e /tmp/stdout ] || touch /tmp/stdout
		[ -e /tmp/stderr ] || touch /tmp/stderr
		tail -f /tmp/stdout > /dev/stdout &
		echo $! >> /tmp/pid-tail-global
		tail -f /tmp/stderr > /dev/stderr &
		echo $! >> /tmp/pid-tail-global

		exec  > /tmp/stdout
		exec 2> /tmp/stderr
		return
	fi
	
	[ -c /dev/kmsg ] || return

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

	# fix the issue when install mysql
	# ERROR: There's not enough space in /var/lib/mysql/
	echo $files | grep -q "mysql" && {
		mkdir -p /tmp/lib/mysql /var/lib/mysql
		mount --bind /tmp/lib/mysql /var/lib/mysql
	}

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

check_rpm_manager()
{
	has_cmd "yum" && installer="yum" && return
	has_cmd "zypper" && installer="zypper"
}

delete_conflict_packages()
{
	local rpms

	rpm -ivh --force --ignoresize --test /opt/rpms/*.rpm 2>conflict_log
	rpms=$(awk -F'conflicts with' '{print $2}' conflict_log | grep -v 'installed')

	[ ! ${rpms} ] && return
	echo "${rpms}" | tr ' ' '\n' | while read rpm; do
		rm -f /opt/rpms/${rpm}.rpm
	done
}

install_opt_rpms()
{
	[ ${installer} = "yum" ] && {
		yum localinstall -y /opt/rpms/*.rpm &>/dev/null
		return
	}
	[ ${installer} = "zypper" ] && {
		zypper install --force-resolution -y /opt/rpms/*.rpm &>/dev/null
		return
	}
}
install_rpms()
{
	[ -d /opt/rpms ] || return
	check_rpm_manager
	install_opt_rpms
	[ "$?" -eq "0" ] || {
		delete_conflict_packages
		rpm -ivh --force --ignoresize /opt/rpms/*.rpm
	}

}

try_get_and_set_distro()
{
	[ -n "$DISTRO" ] && return

	local rootfs=$(grep "rootfs:" $job | cut -d: -f2 | sed 's/ //g')
	DISTRO=${rootfs%%-*}
	DISTRO=${DISTRO##*/}
}

try_install_runtime_depends()
{
	[ "$LKP_LOCAL_RUN" = "1" ] && return

	# 0Day only
	[ "$require_install_depends" != "1" ] && return
	try_get_and_set_distro || return
	[ -f $LKP_SRC/distro/$DISTRO ] || return

	. $LKP_SRC/distro/$DISTRO
	install_runtime_depends $job 2>&1 | grep -v "Out of memory"
}

fixup_packages()
{
	try_install_runtime_depends

	install_deb

	install_rpms

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
	is_docker && return
	check_mount debug /sys/kernel/debug -t debugfs
}

# cache pkg for only one week to avoid "no space left" issue
cleanup_pkg_cache()
{
	local pkg_cache=$1
	local cleanup_stamp=$pkg_cache/cleanup_stamp/$(date +%U)
	[ -d "$cleanup_stamp" ] && return
	mkdir $cleanup_stamp -p

	for delday in $(seq 14 -1 0)
	do
		# df /dev/sda1
		# Filesystem     1K-blocks      Used Available Use% Mounted on
		# /dev/sda1      960380648 316688212 594837976  35% /
		disk_usage=$(df "$rootfs_partition" | grep "$rootfs_partition" | awk '{print $(NF-1)}' | awk -F'%' '{print $1}')
		[ $disk_usage -lt 80 ] && break

		find "$pkg_cache" \( -type f -mtime +${delday} -delete \) -or \( -type d -ctime +${delday} -empty -delete \)
	done
	echo "After clean up pkg cache, $rootfs_partition disk usage is $disk_usage%"
}

wait_load_disk()
{
	local load_disk=$1
	# set the max time of wait is 30s
	for i in $(seq 30)
	do
		# eg: /dev/disk/by-id/ata-WDC_WD1002FAEX-00Z3A0_WD-WCATRC577623-part2
		ls $load_disk >/dev/null 2>&1 && return
		# eg: LABEL=LKP-ROOTFS
		blkid | grep -q ${load_disk#*=} && return
		sleep 1
	done

	return 1
}

add_disk_to_vg()
{
	local one_disk=$1
	local vg_name=os

	# if one_disk is not pv, then pvcreate it.
	pvdisplay $one_disk > /dev/null || {
		# clean the partition table of disk
		dd if=/dev/zero of=$one_disk bs=512K count=1

		# create pv
		pvcreate -y $one_disk || {
		echo "create pv failed: $one_disk"
		return 1
		}
	}

	# if vg not existed: create it by one_disk.
	# if vg existed:     add one_disk to vg,
	if vgdisplay $vg_name > /dev/null; then
		# if pv not in vg: add one_disk to vg
		pvdisplay $one_disk | grep 'VG Name' | grep -w $vg_name || {
			vgextend -y $vg_name $one_disk || {
				echo "vgextend failed: $one_disk"
				return 1
			}
		}
	else
		vgcreate -y $vg_name $one_disk || {
			echo "vgcreate failed: $one_disk"
			return 1
		}
	fi
}

mount_rootfs()
{
	if [ -n "$rootfs_partition" ]; then
		# wait for the machine to load the disk
		wait_load_disk "$rootfs_partition" || {
			# skipping following test if disk can't be load
			echo "can't load the disk $rootfs_partition, skip testing..."
			set_job_state 'load_disk_fail'
			return 1
		}
		ROOTFS_DIR=/opt/rootfs
		mkdir -p $ROOTFS_DIR
		mount $rootfs_partition $ROOTFS_DIR || {
			mkfs.btrfs -f $rootfs_partition
			mount $rootfs_partition $ROOTFS_DIR
		}
		mkdir -p $ROOTFS_DIR/tmp
		CACHE_DIR=$ROOTFS_DIR/tmp
		cleanup_pkg_cache $CACHE_DIR
	elif [ -n "$rootfs_disk" ]; then
		local one_disk
		local vg_name=os

		# activate lvm
		vgscan --cache
		vgchange -ay || vgchange -ay $vg_name

		for one_disk in ${rootfs_disk}
		do
			# wait for the machine to load the disk
			wait_load_disk "$one_disk" || {
				echo "can't load the disk $one_disk, skip testing..."
				set_job_state 'load_disk_fail'
				return 1
			}

			# add disk to vg
			add_disk_to_vg "$one_disk" || {
				echo "can't add disk to vg: $one_disk, skip testing..."
				return 0
			}
		done

		# add CACHE_DIR if testbox have rootfs_disk
		local cache_lv=/dev/mapper/${vg_name}-cache
		[ -b "$cache_lv" ] && lvremove --force $cache_lv
		lvcreate -y -L 8G --name cache "$vg_name" || {
			echo "lvcreate failed: cache"
			return 0
		}

		CACHE_DIR=/tmp/cache
		mkdir -p $CACHE_DIR
		mkfs.ext4 $cache_lv || {
			echo "mkfs.ext4 failed: $cache_lv"
			return 0
		}
		mount $cache_lv $CACHE_DIR || {
			echo "mount cache_lv failed"
			return 0
		}
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

show_default_interface()
{
	if has_cmd ip; then
		ip -4 route list 0/0 | cut -f5 -d' '
	else
		route -n | awk '$4 == "UG" {print $8}'
	fi
}

netconsole_init()
{
	# don't init netconsole at local run
	[ "$LKP_LOCAL_RUN" = "1" ] && return

	[ -z "$netconsole_port" ] && return
	[ -n "$NO_NETWORK" ] && return

	# use default gateway as netconsole server
	netconsole_server=$(show_default_gateway)
	# Select the interface that can access netconsole server
	netconsole_interface=$(show_default_interface)
	[ -n "$netconsole_server" ] || return
	# eth0 is default interface if netconsole_interface is null.
	modprobe netconsole netconsole=@/$netconsole_interface,$netconsole_port@$netconsole_server/
}

download_job()
{
	job="$(grep -m1 '^initrd http://.*/job.cgz' $NEXT_JOB | awk '{print $2}')"
	[ -z "$job" ] && {
		job="$(grep -o 'job=[^ ]*.yaml' $NEXT_JOB | awk -F 'job=' '{print $2}')"
	}

	local job_cgz=$job
	[ "${job_cgz%.cgz}" = "$job_cgz" ] && job_cgz=${job_cgz%.yaml}.cgz

	# TODO: escape is necessary. We might also need download some extra cgz
	http_get_file "$job_cgz" /tmp/next-job.cgz
	(cd /; gzip -dc /tmp/next-job.cgz | cpio -id)
}

__reboot_bad_next_job()
{
	set_tbox_wtmp 'rebooting_bad_next_job'
	sleep 1
	reboot_tbox 2>/dev/null && exit
}

__next_job()
{
	NEXT_JOB="/tmp/next-job-$LKP_USER"

	echo "getting new job..."
	local last_kernel=
	[ -n "$job" ] && last_kernel="last_kernel=$(escape_cgi_param $(grep ^kernel: $job | cut -d \" -f 2))&"
	http_get_cgi "cgi-bin/gpxelinux.cgi?hostname=${HOSTNAME}&mac=$PUB_MAC&${last_kernel}${manual_reboot}lkp_wtmp" \
		$NEXT_JOB || {
		echo "cannot get next job" 1>&2
		set_tbox_wtmp 'cannot_get_next_job'
		return 1
	}

	grep -iq "^KERNEL " $NEXT_JOB || {
		echo "no KERNEL found" 1>&2
		set_tbox_wtmp 'no_kernel_found'
		cat $NEXT_JOB
		return 1
	}

	return 0
}

next_job()
{
	LKP_USER=${pxe_user:-lkp}

	__next_job || {
		[ "$LKP_USER" != "lkp" ] && __reboot_bad_next_job

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

	local append="$(grep -Em1 '^(APPEND|append) ' $NEXT_JOB | sed -r 's/^(APPEND|append) //')"
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

		is_same_cmdline || return 1

		local next_rootfs=$(awk '/^rootfs: /{print $2}' $job)
		[ -n "$next_rootfs" ] || {
			echo "ERROR: no rootfs in the job file: $job"
			return 1
		}

		[ "$rootfs" = "$next_rootfs" ] && return 0
	fi

	return 1
}

is_same_suite()
{
	local current_suite=$suite
	local next_suite=$(awk '/^suite: /{print $2}' $job | tr -d '"')

	[ "$current_suite" = "$next_suite" ]
}

is_same_bp_memmap()
{
	local next_bp_memmap=$(awk '/bp_memmap:/{print $2}' $job)
	# $ awk -F'memmap=' '{print $2}' /proc/cmdline | awk '{print $1}'
	# 32G!4G
	local current_memmap=$(awk -F'memmap=' '{print $2}' /proc/cmdline | awk '{print $1}')

	[ "$next_bp_memmap" = "$current_memmap" ]
}

is_same_cmdline()
{
	local current_kernel_cmdline=$kernel_cmdline
	local next_kernel_cmdline=$(awk '/kernel_cmdline:/{print $2}' $job)

	[ "$current_kernel_cmdline" = "$next_kernel_cmdline" ]
}

setup_env()
{
	[ "$result_service" != "${result_service#9p/}" ] && {
		export VM_VIRTFS=1
		echo "export VM_VIRTFS=1 due to result service $result_service"
	}
}

add_nfs_default_options()
{
	echo "[ NFSMount_Global_Options ]" >>/etc/nfsmount.conf
	echo "  nolock=True" >>/etc/nfsmount.conf
}

# initiation at boot stage; should be invoked once for
# each fresh boot.
boot_init()
{
	deploy_intel_ucode
	setup_env

	mount_kernel_fs
	mount_tmpfs
	resize_virtual_rootfs
	redirect_stdout_stderr

	log_info "Kernel tests: Boot OK!"

	setup_hostname
	setup_hosts
	setup_dns

	add_lkp_user

	fixup_packages

	setup_network
	run_ntpdate
	export_ip_mac

	announce_bootup

	mount_debugfs

	if is_aliyunos; then
		add_nfs_default_options
	fi

	netconsole_init

	mount_rootfs
}

install_pkgs()
{
	[ -d /opt/pkgs ] || return
	echo "install $(ls /opt/pkgs/*.pkg.tar*)"
	pacman -U --needed --noconfirm /opt/pkgs/*.pkg.tar*
}
