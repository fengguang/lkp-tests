#!/bin/sh

#if we pass 'hyperv_synic' to this function, line 7 - 12 will be deleted
#
# ~/lkp/kvm-unit-tests$ cat unittests.cfg -n
#  1 [vmx_null]
#  2 file = vmx.flat
#  3 extra_params = -cpu host,+vmx -append null
#  4 arch = x86_64
#  5 groups = vmx
#  6
#  7 [hyperv_synic]
#  8 file = hyperv_synic.flat
#  9 smp = 2
# 10 extra_params = -cpu kvm64,hv_synic -device hyperv-testdev
# 11 groups = hyperv
# 12
# 13 [hyperv_connections]
# 14 ...
remove_case()
{
	local to_be_removed=$1
	local casesfile="x86/unittests.cfg"

	sl=$(grep "^\[$to_be_removed\]" $casesfile -n | awk -F':' '{print $1}')
	[ -n "$sl" ] || return
	el=$(sed -n "$((sl+1)),$ p" $casesfile | grep '^\[' -n -m 1 | awk -F':' '{print $1}')

	if [ -z "$el" ]; then
		sed -i "$sl,$ d" $casesfile # delete $sl to the end
	else
		el=$((el+sl-1))
		sed -i "$sl,$el d" $casesfile # delete $sl to $el
	fi
}

cpu_support_pku()
{
	lscpu | grep -qw pku
}

check_ignored_cases()
{
	local ignored_by_lkp=$LKP_SRC/pack/"$testcase"-addon/ignored_by_lkp

	cpu_support_pku || {
		remove_case "pku" && echo "ignored_by_lkp: pku"
	}

	[ -f "$ignored_by_lkp" ] || return

	for ignore in $(cat $ignored_by_lkp | grep -v '^#')
	do
		remove_case "$ignore" && echo "ignored_by_lkp: $ignore"
	done
}

load_kvm_intel_nested()
{
	[ -c "/dev/kvm" ] || {
		modprobe kvm_intel nested=y || {
			echo "fail to load kvm_intel with nested=y"
			return 1
		}
	}

	# if nested != 'Y', reload it again
	local nested=$(cat /sys/module/kvm_intel/parameters/nested)

	[ "$nested" = "N" ] && {
		# force load kvm_intel with nested=y
		modprobe -r kvm_intel
		modprobe kvm_intel nested=y || {
			echo "fail to reload kvm_intel with nested=y"
			return 1
		}
	}

	nested=$(cat /sys/module/kvm_intel/parameters/nested)
	[ "$nested" = "N" ] && echo "FIXME: vmx related cases may fail due to host unsupport nested virtualization" && return 1

	return 0
}

setup_test_environment()
{
	# fix "SKIP pmu (/proc/sys/kernel/nmi_watchdog not equal to 0)"
	[ "$(cat /proc/sys/kernel/nmi_watchdog)" != "0" ] && {
		echo 0 > /proc/sys/kernel/nmi_watchdog || return
	}
	[ -z "$(virt-what)" ] && {
		load_kvm_intel_nested || return
	}
	return 0
}

run_tests()
{
	log_cmd ./run_tests.sh
}

upload_test_results()
{
	upload_files -t results $BENCHMARK_ROOT/kvm-unit-tests/logs/*
}

dump_qemu()
{
	# dump debug info
	ldd $QEMU
	lsmod
}
