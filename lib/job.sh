#!/bin/sh

read_env_vars()
{
	[ -f "$TMP/env.yaml" ] || return 0

	local key
	local val

	while read key val
	do
		[ "${key%[a-zA-Z0-9_]:}" != "$key" ] || continue
		key=${key%:}
		export "$key=$val"
	done < $TMP/env.yaml

	return 0
}

wakeup_pre_test()
{
	mkdir $TMP/wakeup_pre_test-once 2>/dev/null || return

	$LKP_SRC/monitors/event/wakeup pre-test
	sleep 1
	date '+%s' > $TMP/start_time
}

should_wait_cluster()
{
	[ -z "$LKP_SERVER" ] && return 1
	[ -z "$node_roles" ] && return 1
	[ "$all_nodes" = "$HOSTNAME" ] && return 1
	return 0
}

wait_other_nodes()
{
	should_wait_cluster || return

	local program_type=$1
	local program=$2
	[ "$program_type" = 'test' ] && echo "$program" >> $TMP/executed-test-programs

	mkdir $TMP/wait_other_nodes-once 2>/dev/null || return

	# exit if either of the other nodes failed its job

	for i in $(seq 100)
	do
		result=$(wget -O - "http://$LKP_SERVER/~$LKP_USER/cgi-bin/lkp-cluster-sync?cluster=$cluster&node=$HOSTNAME" |
			 grep -o -w -F -e 'ready' -e 'retry' -e 'abort')
		case $result in
		'abort')
			echo "cluster.abort: 1" >> $RESULT_ROOT/last_state
			exit
			;;
		'ready')
			return
			;;
		'retry')
			;;
		esac
	done

	wget -O /dev/null "http://$LKP_SERVER/~$LKP_USER/cgi-bin/lkp-cluster-sync?cluster=$cluster&node=$HOSTNAME&abort=true"
}

# In a cluster test, if some server/service role only started daemon(s) and
# finished the job quickly, wait until the clients have finished with their
# test jobs.
wait_clients_finish()
{
	[ -n "$node_roles" ] || return
	[ "$all_nodes" = "$HOSTNAME" ] && return
	[ -f "$TMP/executed-test-programs" ] && return

	# contact LKP server, it knows whether all clients have finished
	:
}

check_exit_code()
{
	local exit_code=$1

	[ "$exit_code" = 0 ] && return

	echo "${program}.exit_code.$exit_code: 1" >> $RESULT_ROOT/last_state
	should_wait_cluster && wget -O /dev/null "http://$LKP_SERVER/~$LKP_USER/cgi-bin/lkp-cluster-sync?cluster=$cluster&node=$HOSTNAME&failed=true"
	exit "$exit_code"
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

start_daemon()
{
	local program=${1##*/}
	"$@"
	check_exit_code $?

	# If failed to start the daemon above, the job will abort.
	# LKP server on notice of the failed job will abort the other waiting nodes.

	wait_other_nodes 'daemon' $program
	wakeup_pre_test
}

run_test()
{
	local program=${2##*/}
	wait_other_nodes 'test' $program
	wakeup_pre_test
	"$@"
	check_exit_code $?
}

