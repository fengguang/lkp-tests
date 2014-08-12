#!/bin/bash

WAIT_POST_TEST_CMD="$LKP_SRC/monitors/event/wait post-test"

wait_post_test()
{
	$WAIT_POST_TEST_CMD
}

echo $$ >> $TMP/.pid-wait-monitors
