#!/bin/bash

read_env_vars()
{
	eval $(sed -e '/^ *$/d;/^#/d;s/^/export /;s/: */=\"/g;s/$/\"/g;s/ *=/=/g' $TMP/env.yaml)
}

wakeup_pre_test()
{
	mkdir $TMP/wakeup_pre_test-once 2>/dev/null || return

	$LKP_SRC/monitors/event/wakeup pre-test
	sleep 1
	date '+%s' > $TMP/start_time
}

check_exit_code()
{
	local exit_code=$1

	(( $exit_code == 0 )) && return

	echo "${program}.exit_code.$exit_code: 1" >> $RESULT_ROOT/last_state
	exit $exit_code
}

run_monitor()
{
	"$@"
}

run_setup()
{
	local program=${1##*/}
	"$@"
	check_exit_code $?
	read_env_vars
}

run_test()
{
	local program=${2##*/}
	wakeup_pre_test
	"$@"
	check_exit_code $?
}

