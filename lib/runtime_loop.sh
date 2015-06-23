#!/bin/sh

report_ops()
{
	stop_time=$(date +%s)
	echo ops: $(echo "x = $operations / ($stop_time - $start_time); if (x < 1) print 0; x" | bc -l)
	exit
}

test_loop()
{
	trap report_ops SIGHUP

	start_time=$(date +%s)
	operations=0

	while :
	do
		do_test
		operations=$((operations + 1))
	done
}

runtime_loop()
{
	test_loop &
	sleep $runtime
	kill -s SIGHUP %1
	wait
}
