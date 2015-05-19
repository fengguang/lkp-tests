#!/bin/bash

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
