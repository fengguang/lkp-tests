#!/bin/sh
# - test

## Utilities for testing Power Management

cd $BENCHMARK_ROOT/pm-qa || exit

. $LKP_SRC/lib/upload.sh

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

if [ "$test" = 'all' ]; then
	for i in cpufreq cpuhotplug cputopology cpuidle thermal
	do
		run_one $i
	done
else
	run_one $test
fi
