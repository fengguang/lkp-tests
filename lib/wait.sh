#!/bin/sh

WAIT_POST_TEST_CMD="$LKP_SRC/monitors/event/wait post-test"

wait_post_test()
{
	$WAIT_POST_TEST_CMD "$@"
}

wait_job_finished()
{
	$WAIT_JOB_FINISHED_CMD "$@"
}

wait_timeout()
{
	local timeout="${1:-1}"
	local exit_code

	# wait returns
	# - 0 on post-test => job finished, let's exit too
	# - 62 on timeout
	# - others on error => exit to avoid busy looping on caller side
	$WAIT_POST_TEST_CMD --timeout "$timeout"
	exit_code=$?
	[ $exit_code -eq 62 ] || exit $exit_code
}

setup_wait()
{
	echo $$ >> $TMP/.pid-wait-monitors
	echo ${0##*/} >> $TMP/.name-wait-monitors
}

kill_one()
{
	kill    $* 2>/dev/null
	sleep 3
	kill -9 $* 2>/dev/null
}

kill_tests()
{
	local pid_tests=$(cat $TMP/pid-tests)
	local pid_job=$(cat $TMP/run-job.pid)

	kill_one $pid_tests
	sleep 3
	kill_one $pid_job
}
