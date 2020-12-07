#!/bin/sh
# - test

## Utilities for testing Power Management

. $LKP_SRC/lib/upload.sh
. $LKP_SRC/lib/reproduce-log.sh

cd $BENCHMARK_ROOT/pm-qa || die "no $BENCHMARK_ROOT/pm-qa"

[ -e "/usr/bin/glmark2" ] || ln -sf /lkp/benchmarks/pm-qa/glmark2/bin/glmark2 /usr/bin/glmark2

run_one()
{
	local testcase=$1
	local ret_value

	if [ "$testcase" = 'cpuhotplug' ]; then
		ext_opt='hotplug_allow_cpu0=0'
	else
		ext_opt=
	fi

	log_cmd make -C $testcase $ext_opt run_tests

	ret_value=$?

	upload_files -t results $BENCHMARK_ROOT/pm-qa/$testcase/*.log

	return $ret_value
}

check_ignored_by_lkp()
{
	local test=$1
	local ignored_by_lkp=$LKP_SRC/pkg/pm-qa/addon/ignored_by_lkp

	for ignore in $(cat $ignored_by_lkp | grep -v ^#)
	do
		[ -f "$test/$ignore".sh ] && mv $test/$ignore.sh $test/$ignore.sh.bak && echo "$ignore: ignored_by_lkp"
	done
}

# remove the noise module
# this module will create /sys/devices/virtual/thermal/thermal_zone2 dir, but it will not create
# file: /sys/devices/virtual/thermal/thermal_zone2/mode which is expected by the tests
rmmod x86_pkg_temp_thermal 2>/dev/null

if [ "$test" = 'all' ]; then
	for i in cpufreq cpuhotplug cputopology cpuidle thermal
	do
		check_ignored_by_lkp $i
		run_one $i
	done
else
	check_ignored_by_lkp $test
	run_one $test
fi
