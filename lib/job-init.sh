mount_cgroup()
{
	[ -f "$CGROUP_MNT/tasks" ] && return
	awk 'NR > 1 {print "\\s\\+" $1 "\\."}' /proc/cgroups > $TMP/availble-cgroup_subsys
	cgroup_subsys=$(grep -o -f $TMP/availble-cgroup_subsys $job)
	[ -n "$cgroup_subsys" ] || return
	cgroup_subsys=$(echo $cgroup_subsys | sed -e 's/\. /,/g' -e 's/\.$//')
	log_cmd mkdir -p $CGROUP_MNT
	log_cmd mount -t cgroup -o $cgroup_subsys none $CGROUP_MNT
}

validate_result_root()
{
	[ -n "$RESULT_ROOT" ] || RESULT_ROOT=$result_root
	[ -n "$RESULT_ROOT" ] || {
		echo 'No RESULT_ROOT' >&2
		run_job_failed=1
		return 1
	}

	return 0
}

should_do_cifs()
{
	grep -q clear-linux-os /etc/os-release && return 0
	grep -q -w 'nfs' /proc/filesystems && return 1
	modprobe nfs 2>/dev/null
	grep -q -w 'nfs' /proc/filesystems && return 1
	return 0
}

mount_result_root()
{
	is_mount_point $RESULT_MNT && return 0

	[ -n "$result_service" ] || {
		if should_do_cifs; then
			result_service=//$LKP_SERVER/result
		else
			result_service=$LKP_SERVER:/result
		fi
	}

	case $result_service in
		*:*)
			result_fs=nfs
			mount.nfs $result_service $RESULT_MNT || return
			;;
		//*/*)
			result_fs=cifs
			modprobe cifs 2>/dev/null
			local cifs_mount_option='-o guest'
			[ -n "$LKP_CIFS_PORT" ] && cifs_mount_option="$cifs_mount_option,port=$LKP_CIFS_PORT"
			mount.cifs $cifs_mount_option $result_service $RESULT_MNT || return
			;;
		9p/*)
			result_fs=virtfs
			mkdir -p -m 02775 $RESULT_ROOT
			export RESULT_MNT=$RESULT_ROOT
			export TMP_RESULT_ROOT=$RESULT_ROOT
			mkdir -p $TMP
			mount -t 9p -o trans=virtio $result_service $RESULT_MNT  -oversion=9p2000.L,posixacl,cache=loose
			;;
		*)
			echo "unknown result_service $result_service" >&2
			return 1
			;;
	esac

	mountpoint -q $RESULT_MNT
}

setup_result_root()
{
	validate_result_root || return 1

	echo RESULT_ROOT=$RESULT_ROOT
	echo job=$job

	export TMP_RESULT_ROOT=$TMP/result
	mkdir -p $TMP_RESULT_ROOT

	[ -n "$NO_NETWORK" ] && {
		export RESULT_ROOT=$TMP_RESULT_ROOT
		return
	}

	RESULT_PREFIX=/$LKP_SERVER
	export RESULT_ROOT=$RESULT_PREFIX$RESULT_ROOT
	export RESULT_MNT=$RESULT_PREFIX/result

	mkdir -p $RESULT_MNT
	mount_result_root $RESULT_MNT || {
		if [ -z "$result_fs" ]; then
			set_job_state "unknown_result_service"
		elif grep -q -w "$result_fs" /proc/filesystems; then
			set_job_state 'error_mount'
			sleep 300
		else
			set_job_state "miss_$result_fs"
		fi
		return 1
	}

	# check emptiness except for files: dmesg pre-dmesg
	ls $RESULT_ROOT | grep -v -q -F dmesg &&
	echo "RESULT_ROOT not empty: $(ls -l $RESULT_ROOT)" >&2

	return 0
}

# in case someone is logged in, give him at most 10hour time to do manual checks
wait_on_manual_check()
{
	# extra sleep for user login after a failed job,
	# if "wait_debug_on_fail" is defined in the job file
	[ "$run_job_failed" != 0 ] && [ -n "$wait_debug_on_fail" ] && {
		sleep $wait_debug_on_fail
	}

	for i in $(seq 600)
	do
		if [ -f $TMP/disturbed ]; then
			:
		# t100 has XWindow auto login
		elif [ "$HOSTNAME" = 't100' ]; then
			local users="$(users)"
			[ "${users#* }" != "$users" ] || break
		else
			[ -n "$(users)" ] || break
		fi
		disturbed=1
		[ "$i" = 1 ] && set_job_state 'manual_check'
		sleep 60
	done
	return $disturbed
}

clean_job_resource()
{
	killall tail-to-lkp
}

job_done() {
	$LKP_SRC/bin/event/wakeup job-finished
	touch $TMP/job-finished
	clean_job_resource
	wait_on_manual_check

	[ -z "$disturbed" ] && trigger_post_process

	exit $1
}

refresh_lkp_tmp()
{
	export TMP=/tmp/lkp
	rm -fr $TMP
	mkdir -p $TMP
}

job_redirect_stdout_stderr()
{
	ln -sf /usr/bin/tail /bin/tail-to-lkp

	tail-to-lkp -n 0 -f /tmp/stdout > $TMP/stdout &
	tail-to-lkp -n 0 -f /tmp/stderr > $TMP/stderr &

	tail-to-lkp -n 0 -f /tmp/stdout /tmp/stderr > $TMP/output &
}

job_env()
{
	if echo $job_file | grep -q '\.sh$'; then
		. $job_file
	else
		. ${job_file%.yaml}.sh
	fi

	export_top_env
}

# per-job initiation; should be invoked before run a job
job_init()
{
	refresh_lkp_tmp
	cp /proc/uptime $TMP/boot-time

	job_redirect_stdout_stderr

	job_env
}
