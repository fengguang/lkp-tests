#!/bin/bash

report_ops()
{
	stop_time=$(date +%s)
	echo ops: $(( operations / (stop_time - start_time) ))
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
		(( operations++ ))
	done
}

test_loop &
sleep $runtime
kill -s SIGHUP %1
wait
