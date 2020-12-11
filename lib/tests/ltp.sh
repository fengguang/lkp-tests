#!/bin/bash

rebuild()
{
	[ -d "$1" ] || return
	local build_dir=$1
	local current_dir=$(pwd)

	cd $build_dir && {
		make clean || return
		make || return
		cd $current_dir
	}
}

build_ltp()
{
	make autotools
	./configure --prefix=$1
	make || return

	# fix rpc test cases, linking to libtirpc-dev will make the tests failed in debian
	sed -i "s/^LDLIBS/#LDLIBS/" testcases/network/rpc/rpc-tirpc/tests_pack/Makefile.inc || return
	rebuild testcases/network/rpc/rpc-tirpc/tests_pack/rpc_suite/rpc/rpc_createdestroy_svc_destroy || return
	rebuild testcases/network/rpc/rpc-tirpc/tests_pack/rpc_suite/rpc/rpc_createdestroy_svcfd_create || return
	rebuild testcases/network/rpc/rpc-tirpc/tests_pack/rpc_suite/rpc/rpc_regunreg_xprt_register || return
	rebuild testcases/network/rpc/rpc-tirpc/tests_pack/rpc_suite/rpc/rpc_regunreg_xprt_unregister
}

install_ltp()
{
	make install
	cp testcases/commands/tpm-tools/tpmtoken/tpmtoken_import/tpmtoken_import_openssl.cnf $1/testcases/bin/
	cp testcases/commands/tpm-tools/tpmtoken/tpmtoken_protect/tpmtoken_protect_data.txt  $1/testcases/bin/
}

is_excluded()
{
	test=$1
	local exclude_file=$LKP_SRC/pkg/ltp/addon/exclude
	cp $exclude_file ./exclude

	# regex match
	for regex in $(cat "$exclude_file" | grep -v '^#' | grep -w ^${test}:.*:regex$ | awk -F: 'NF == 3 {print $2}')
	do
		echo "# regex: $regex generated" >> ./exclude
		cat runtest/$test | awk '{print $1}' | grep -G "$regex" | awk -v prefix=$test":" '$0=prefix$0' >> ./exclude
	done

	orig_test=$(echo "$test" | sed 's/-[0-9]\{2\}$//')
	for i in $(cat ./exclude | grep -v '^#' | grep -w ^$orig_test | awk -F: 'NF == 2')
	do
		ignore=$(echo $i | awk -F: '{print $2}')
		grep -q "^${ignore}" runtest/${test} || continue
		sed -i "s/^${ignore} /#${ignore} /g" runtest/${test}
		echo "<<<test_start>>>"
		echo "tag=${ignore}"
		echo "${ignore} 0 exclude"
		echo "<<<test_end>>>"
	done
}

workaround_env()
{
	# some LTP sh scripts actually need bash. Fixes
	# > netns_childns.sh: 38: .: cmdlib.sh: not found
	[ "$(cmd_path bash)" = '/bin/bash' ] && [ $(readlink -e /bin/sh) != '/bin/bash' ] &&
	ln -fs bash /bin/sh

	# install mkisofs which is linked to genisoimage
	command -v mkisofs || {
		genisoimage=$(command -v genisoimage)
		if [ -n "$genisoimage" ]; then
			log_cmd ln -sf "$genisoimage" /usr/bin/mkisofs
		else
			echo "can not install mkisofs"
		fi
	}
}

specify_tmpdir()
{
	[ -z "$partitions" ] && return 1
	ltp_partition="${partitions%% *}"
	mount_point=/fs/$(basename $ltp_partition)

	mkdir -p $mount_point/tmpdir || return 1
	tmpdir_opt="-d $mount_point/tmpdir"

	return 0
}

test_setting()
{
	case "$test" in
	cpuhotplug)
		mkdir -p /usr/src/linux/
		;;
	fs_readonly-0*)
		[ -z "$fs" ] && exit
		[ -z "$partitions" ] && exit
		big_dev="${partitions%% *}"
		umount $big_dev
		big_dev_opt="-Z $fs -z $big_dev"
		;;
	fs_ext4)
		[ -z "$partitions" ] && exit
		big_dev="${partitions%% *}"
		big_dev_opt="-z $big_dev"
		# match logic of is_excluded
		sed -i "s/\t/ /g" runtest/fs_ext4
		;;
	lvm.local)
		export LTPROOT=${PWD}
		export PATH="$PATH:$LTPROOT/testcases/bin"
		# Creates runtest/lvm.local with testcases for all locally supported FS types
		log_cmd testcases/bin/generate_lvm_runfile.sh
		# Creates 2 LVM volume groups and mounts logical volumes for all locally supported FS types
		log_cmd testcases/bin/prepare_lvm.sh
		;;
	mm-oom|mm-min_free_kbytes)
		local pid_job="$(cat $TMP/run-job.pid)"
		echo 0 > /proc/$pid_job/oom_score_adj
		;;
	mm-00)
		[ -z "$partitions" ] && exit
		swap_partition="${partitions%% *}"
		mkswap $swap_partition 2>&1 || exit 1
		swapon $swap_partition
		;;
	tpm_tools)
		[ $USER ] || USER=root
		rm -rf /var/lib/opencryptoki/tpm/$USER
		cd tpm-emulater
		find . -maxdepth 1 -type d -name "TPM_Emulator*" -exec rm -rf {} \;
		unzip $(ls TPM_Emulator*.zip | head -1)
		rsync -av $(ls -l . | awk '/^d/ {print $NF}' | head -1)"/" /
		cd ..
		killall tpmd > /dev/null 2>&1
		tpmd -f -d clear > /dev/null 2>&1 &
		killall tcsd > /dev/null 2>&1
		tcsd -e -f > /dev/null 2>&1 &
		sleep 5
		export LTPROOT=${PWD}
		export LTPBIN=$LTPROOT/testcases/bin
		export OWN_PWD="HELLO1"
		export NEW_OWN_PWD="HELLO2"
		export SRK_PWD="HELLO3"
		export NEW_SRK_PWD="HELLO4"
		export P11_SO_PWD="HELLO5"
		export NEW_P11_SO_PWD="HELLO6"
		export P11_USER_PWD="HELLO7"
		export NEW_P11_USER_PWD="HELLO8"
		;;
	ltp-aiodio.part[24]|dio-0*|io)
		specify_tmpdir || exit
		;;
	syscalls-ipc-msgstress)
		# avoid soft_timeout by reducing the max number of message
		# queues to 10000(default is 32000)
		echo 10000 > /proc/sys/kernel/msgmni
		;;
	syscalls-0*)
		export LTP_TIMEOUT_MUL=5
		specify_tmpdir || exit

		relatime=$(mount | grep /tmp | grep relatime)
		noatime=$(mount | grep /tmp | grep noatime)
		if [ "$relatime" != "" ] || [ "$noatime" != "" ]; then
			mount -o remount,strictatime /tmp
		fi

		echo "#\$SystemLogSocketName /run/systemd/journal/syslog" > /etc/rsyslog.d/listen.conf
		systemctl restart rsyslog || exit
		[ -f /var/log/maillog ] || {
			touch /var/log/maillog && chmod 600 /var/log/maillog
		}
		[ -e /dev/log ] && rm /dev/log
		ln -s /run/systemd/journal/dev-log /dev/log
		;;
	net.ipv6_lib)
		iface=$(ifconfig -s | awk '{print $1}' | grep ^eth | head -1)
		[ -n "$iface" ] && export LHOST_IFACES=$iface
		sed -i "1s/^/::1 ${HOSTNAME}\n/" /etc/hosts
		sed -i "1s/^/127.0.0.1 ${HOSTNAME}\n/" /etc/hosts
		;;
	net.rpc)
		systemctl start openbsd-inetd || exit
		cp netkit-rusers/bin/rup /usr/bin/
		;;
	net_stress.appl-0*)
		[ -d /srv/ftp ] && export FTP_DOWNLOAD_DIR=/srv/ftp
		sed -i '/\/usr\/sbin\/named {/a\\/tmp\/** rw,' /etc/apparmor.d/usr.sbin.named || exit
		systemctl start bind9 || exit
		systemctl list-units | grep -wq apparmor.service && (systemctl reload-or-restart apparmor || exit)
		;;
	scsi_debug.part1-*)
		# fix 'Unable to make dir /test/growfiles/XXX' error
		mkdir -p /test/growfiles
		;;
	esac
}

cleanup_ltp()
{
	case "$test" in
	lvm.local)
		export LTPROOT=${PWD}
		export PATH="$PATH:$LTPROOT/testcases/bin"
		# remove LVM volume groups created by prepare_lvm.sh and release the associated loop devices
		log_cmd testcases/bin/cleanup_lvm.sh
		;;
	mm-oom|mm-min_free_kbytes)
		dmesg -C || exit
		;;
	syscalls-0*)
		[ "$relatime" != "" ] && mount -o remount,relatime /tmp
		[ "$noatime" != "" ] && mount -o remount,noatime /tmp
		;;
	esac

}
