#!/bin/bash

kernel=${1:-vmlinuz}
initrd=${2:-rootfs.cgz}
hostname=${3:-vm-kexec}

kvm=(
	qemu-system-x86_64 -cpu kvm64 -enable-kvm

	-kernel $kernel
	-initrd $initrd

	-smp 2
	-m 2G

	-net nic,vlan=0,macaddr=00:00:00:00:00:ff,model=e1000
	-net user,vlan=0,hostfwd=tcp::2222-:22

	-boot order=nc
	-no-reboot
	-watchdog i6300esb

	-display none
	-serial stdio
	-monitor null
)

append=(
	debug
	sched_debug
	apic=debug
	ignore_loglevel
	earlyprintk=ttyS0,115200
	sysrq_always_enabled
	panic=10
	hung_task_panic=1
	softlockup_panic=1
	nmi_watchdog=panic
	prompt_ramdisk=0
	console=ttyS0,115200
	console=tty0
	vga=normal
	root=/dev/ram0
	rcupdate.rcu_cpu_stall_timeout=100
	drbd.minor_count=8
	rw

	path_prefix='http://bee.sh.intel.com/~lkp/'
	hostname=$hostname
)

"${kvm[@]}" --append "${append[*]}"
