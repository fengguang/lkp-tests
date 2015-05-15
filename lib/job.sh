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
	[ "$cluster" = "cs-localhost" ] && return 1
	return 0
}

sync_cluster_state()
{
	local state_option
	[ -n "$1" ] && state_option="&state=$1"
	[ -n "$2" ] && {
		shift 1
		other_options="&$(IFS='&' && echo -n "$*")"
	}
	should_wait_cluster && wget -O - "http://$LKP_SERVER/~$LKP_USER/cgi-bin/lkp-cluster-sync?cluster=$cluster&node=$HOSTNAME$state_option$other_options"
	:
}

wait_cluster_state()
{
	for i in $(seq 100)
	do
		result=$(sync_cluster_state $1)
		case $result in
		'abort')
			echo "cluster.abort: 1" >> $RESULT_ROOT/last_state
			exit
			;;
		'ready')
			return
			;;
		'finish')
			return
			;;
		'retry')
			;;
		esac
	done

	sync_cluster_state 'abort'
}

wait_other_nodes()
{
	should_wait_cluster || return

	local program_type=$1
	local program=$2
	[ "$program_type" = 'test' ] && echo "$program" >> $TMP/executed-test-programs

	mkdir $TMP/wait_other_nodes-once 2>/dev/null || return

	sync_cluster_state 'write_state' "node_roles=${node_roles// /+}" \
					 "ip=$(hostname -I | cut -d' ' -f1)" \
					 "direct_macs=${direct_macs// /+}" \
					 "direct_ips=${direct_ips// /+}"

	[ -n "$direct_macs" ] && {
		local macs_arr=($direct_macs)
		local ips_arr=($direct_ips)
		for idx in $(seq 0 $((${#macs_arr[@]} - 1)))
		do
			DIRECT_DEVICE=$(ip link | grep -B1 ${macs_arr[$idx]} | awk -F': ' 'NR==1 {print $2}') \
			DIRECT_IP=${ips_arr[$idx]} \
			$LKP_DEBUG_PREFIX $LKP_SRC/bin/run-ipconfig
		done
	}

	# exit if either of the other nodes failed its job

	wait_cluster_state 'wait_ready'

	while read line; do
		export "$line"
	done <<EOF
$(sync_cluster_state 'roles_ip')
EOF
}

# In a cluster test, if some server/service role only started daemon(s) and
# finished the job quickly, wait until the clients have finished with their
# test jobs.
wait_clients_finish()
{
	[ -n "$node_roles" ] || return
	[ "$cluster" = "cs-localhost" ] && return
	[ -f "$TMP/executed-test-programs" ] && return

	# contact LKP server, it knows whether all clients have finished
	wait_cluster_state 'wait_finish'
}

check_exit_code()
{
	local exit_code=$1

	[ "$exit_code" = 0 ] && return

	echo "${program}.exit_code.$exit_code: 1"	>> $RESULT_ROOT/last_state
	echo "exit_fail: 1"				>> $RESULT_ROOT/last_state
	sync_cluster_state 'failed'
	exit "$exit_code"
}

run_monitor()
{
	"$@"
}

run_setup()
{
	local program=${1##*/}
	[ "$program" = 'wrapper' ] && program=$2
	"$@"
	check_exit_code $?
	read_env_vars
}

start_daemon()
{
	local program=${1##*/}
	[ "$program" = 'wrapper' ] && program=$2
	"$@"
	check_exit_code $?

	sync_cluster_state 'finished'
	# If failed to start the daemon above, the job will abort.
	# LKP server on notice of the failed job will abort the other waiting nodes.

	wait_other_nodes 'daemon' $program
	wakeup_pre_test
	wait_clients_finish
}

run_test()
{
	local program=${1##*/}
	[ "$program" = 'wrapper' ] && program=$2
	wait_other_nodes 'test' $program
	wakeup_pre_test
	"$@"
	check_exit_code $?
	sync_cluster_state 'finished'
}

