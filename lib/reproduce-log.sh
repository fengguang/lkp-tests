#!/bin/sh

log_echo()
{
	date=$(date +'%F %T')
	echo "$date $@"
	echo "$@" >> $TMP_RESULT_ROOT/reproduce.sh
}

log_eval()
{
	log_echo "$@"
	eval "$@"
}

log_cmd()
{
	log_echo "$@"
	"$@"
}
