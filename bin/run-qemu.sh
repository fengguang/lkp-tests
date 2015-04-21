#!/bin/bash

usage()
{
	cat <<EOF
Usage: run-qemu.sh [-o RESULT_ROOT] job.sh job.yaml

options:
	-o  RESULT_ROOT		 dir for storing all results

Note:
This script uses qemu to start a VM to run LKP test-job.
It downloads kernel, initrd, bm_initrd, modules_initrd through LKP_SERVER,
and  generates lkp-initrd locally and creates job-initrd with 'job.sh' and 'job.yaml' you specified.

You can check test results in dir '/tmp/vm_test_result/' or a RESULT_ROOT you specified.
EOF
	exit 1
}

create_lkp_initrd()
{
	local local_src_dir=$1
	local tmp_dir=/tmp/lkp_initrd
	local tmp_src=$tmp_dir/lkp/$user/src
	local archive=$tmp_dir/lkp/$user/lkp-x86_64
	make -C $local_src_dir/monitors/event wakeup

	[ -d $tmp_src ] && rm -rf $tmp_dir

	mkdir -p $tmp_src
	find $local_src_dir -mindepth 1 -maxdepth 1 -exec cp -a {} $tmp_src \;
	(cd $tmp_dir && find lkp | cpio -o  -H newc -F $archive.cpio
	 cd $tmp_dir/lkp/$user/src/rootfs/addon		&& find * | cpio -o  -H newc -F $archive.cpio --append)
	 gzip -n -9 $archive.cpio
	 mv -f	  $archive.cpio.gz $archive.cgz

	lkp_initrd=$archive.cgz
}

create_job_initrd()
{
	mkdir -p /tmp$job_initrd_dir
	cp $job_yaml /tmp$job_file
	cp $job_script /tmp${job_file%.yaml}.sh
	archive=/tmp${job_file%.yaml}
	(cd /tmp && find lkp | cpio -o -H newc -F $archive.cpio
	 gzip -n -9 $archive.cpio
	 mv -f $archive.cpio.gz $archive.cgz)
}

while getopts "o:" opt
do
	case $opt in
		o ) opt_result_root="$OPTARG" ;;
		? ) usage ;;
	esac
done

shift $(($OPTIND-1))

job_script=$1
job_yaml=$2

[ -n "$job_script" ] || usage
[ -n "$job_yaml" ] || usage
. $job_script
export_top_env

# create lkp-x86_64.cgz
srcpath=$(dirname $(dirname $(readlink -e -v $0)))
create_lkp_initrd $srcpath

# create job_initrd.cgz
job_initrd=/tmp${job_file%.yaml}.cgz
job_initrd_dir=${job_file%/*}
create_job_initrd

# if job.sh not include bootloader_append entry, add default content
if [ -n "$bootloader_append" ]; then
	bootloader_append=$(echo "$bootloader_append" | tr '\n' ' ')
else
	bootloader_append="root=/dev/ram0 job=$job_file user=$user  ARCH=x86_64 kconfig=x86_64-rhel commit=051d101ddcd268a7429d6892c089c1c0858df20b branch=linux-devel/devel-hourly-2015033109 max_uptime=1247 RESULT_ROOT=$result_root earlyprintk=ttyS0,115200 rd.udev.log-priority=err systemd.log_target=journal systemd.log_level=warning debug apic=debug sysrq_always_enabled rcupdate.rcu_cpu_stall_timeout=100 panic=-1 softlockup_panic=1 nmi_watchdog=panic oops=panic load_ramdisk=2 prompt_ramdisk=0 console=ttyS0,115200 console=tty0 vga=normal rw"
fi

# create vm result path
if [ -z $opt_result_root ]; then
	vm_result_path="/tmp/vm_test_result/$testcase-$(date '+%F-%T')"
else
	vm_result_path=$opt_result_root
fi
mkdir -p $vm_result_path

# download kernel and initrds, then cat them
LKP_SERVER=bee.sh.intel.com
initrd=/osimage/debian/$rootfs
CACHE_DIR=/tmp/lkp-qemu-downloads
[ -d $CACHE_DIR ] || mkdir $CACHE_DIR
LKP_USER="lkp"

download_kernel_initrd()
{
	local _initrd
	local initrds
	kernel=$(echo $kernel| sed 's/^\///')
	kernel_file=$CACHE_DIR/$kernel

	echo "downloading kernel image ..."
	wget "http://$LKP_SERVER/~$LKP_USER/$kernel" -nv -N -P $(dirname $kernel_file) || {
		echo "failed to download kernel: $kernel" 1>&2
		exit 1
	}

	echo "downloading initrds ..."
	for _initrd in $(echo $initrd $tbox_initrd $bm_initrd $modules_initrd  | tr , ' ') # not download lkp_initrd job_initrd
	do
		_initrd=$(echo $_initrd | sed 's/^\///')
		local file=$CACHE_DIR/$_initrd
		wget -nv -N "http://$LKP_SERVER/~$LKP_USER/$_initrd" -P $(dirname $file) || {
			echo ls Failed to download $_initrd
			exit 1
		}
		initrds="${initrds}$file "
	done

	[ -n "$initrds" ] && {
		concatenate_initrd="$CACHE_DIR/initrd-$$"
		cat $initrds $lkp_initrd $job_initrd > $concatenate_initrd
		initrd_option="-initrd $concatenate_initrd"
	}
	return 0
}

run_kvm()
{
	trap - EXIT

	local mem_mb=1024
	local mount_tag=9p/virtfs_mount
	model='qemu-system-x86_64 -enable-kvm'
	netdev_option="-device e1000,netdev=net0 "
	netdev_option+="-netdev user,id=net0"
	KVM_COMMAND=(
		$model
		-fsdev local,id=test_dev,path=$vm_result_path,security_model=none -device virtio-9p-pci,fsdev=test_dev,mount_tag=$mount_tag
		-kernel $kernel_file
		-append "$bootloader_append ip=dhcp result_service=$mount_tag"
		$initrd_option
		-m $mem_mb
		-$netdev_option
		$console
	)
	echo "exec command: ${KVM_COMMAND[@]}"
	"${KVM_COMMAND[@]}"
}

download_kernel_initrd
run_kvm
