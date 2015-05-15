mount_cgroup()
{
	[ -f "$CGROUP_MNT/tasks" ] && return
	awk 'NR > 1 {print "\\s\\+" $1 "\\."}' /proc/cgroups > $TMP/availble-cgroup_subsys
	cgroup_subsys=$(grep -o -f $TMP/availble-cgroup_subsys $job)
	[ -n "$cgroup_subsys" ] || return
	cgroup_subsys=$(echo $cgroup_subsys | sed -e 's/\. /,/g' -e 's/\.$//')
	cmd mkdir -p $CGROUP_MNT
	cmd mount -t cgroup -o $cgroup_subsys none $CGROUP_MNT
}

validate_result_root()
{
	[ -n "$RESULT_ROOT" ] || RESULT_ROOT=$result_root
	[ -n "$RESULT_ROOT" ] || {
		echo 'No RESULT_ROOT' >&2
		run_job_failed=1
		job_done_boot_next
	}
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
			mount.cifs -o guest $result_service $RESULT_MNT || return
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
	validate_result_root

	echo RESULT_ROOT=$RESULT_ROOT
	echo job=$job

	export TMP_RESULT_ROOT=$TMP/result
	mkdir -p $TMP_RESULT_ROOT

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
		job_done_boot_next
	}

	local files="$(echo $RESULT_ROOT/*)"
	[ -e "${files%% *}" ] && echo "RESULT_ROOT not empty: $(ls -l $RESULT_ROOT)" >&2
}

record_dmesg()
{
	killall rsyslogd klogd 2>/dev/null || :
	dmesg > $RESULT_ROOT/dmesg
	ln -s $(command -v cat) $LKP_SRC/bin/cat-kmsg
	stdbuf -o0 -e0 cat-kmsg /proc/kmsg >> $RESULT_ROOT/dmesg &
	echo $! > $TMP/pid-dmesg
	[ -n "$BASH_VERSION" ] && disown # quiet the "Terminated" notification to stderr

	[ -n "$netconsole_port" ] && {
		# use default gateway as netconsole server
		netconsole_server=$(ip -4 route list 0/0 | cut -f3 -d' ')
		modprobe netconsole netconsole=@/,$netconsole_port@$netconsole_server/ 2>/dev/null
	}
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
		# t100 has XWindow auto login
		if [ "$HOSTNAME" = 't100' ]; then
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

tbox_cant_kexec()
{
	[ "$(virt-what)" = 'kvm' ] && return 0

	# following tbox are buggy while using kexec to boot
	[ "${HOSTNAME#*lkp-nex04}"	!= "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-t410}"	!= "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-bdw01}"	!= "$HOSTNAME" ] && return 0
	[ "${HOSTNAME#*lkp-bdw02}"	!= "$HOSTNAME" ] && return 0

	[ -x '/sbin/kexec' ] || return 0

	return 1
}

jobfile_append_var()
{
	local i
	for i
	do
		echo "$i" >> $job_script
	done
}

set_job_state()
{
	jobfile_append_var "job_state=$1"
}

job_done()
{
	:
}

boot_next()
{
	tbox_cant_kexec && {
		reboot 2>/dev/null
		exit
	}

	local secs=300
	while true
	do
		$LKP_SRC/bin/kexec-lkp $pxe_user
		sleep $secs || exit # killed by reboot
		secs=$(( secs + 300 ))
	done
}

job_done_boot_next() {
	touch $TMP/job-finished
	wait_on_manual_check
	[ -n "$disturbed" ] || job_done
	boot_next
}
job_redirect_stdout_stderr()
{
	ln -s /usr/bin/tail /bin/tail-to-lkp

	tail-to-lkp -n 0 -f /tmp/stdout > $TMP/stdout &
	tail-to-lkp -n 0 -f /tmp/stderr > $TMP/stderr &

	tail-to-lkp -n 0 -f /tmp/stdout /tmp/stderr > $TMP/output &
}

# per-job initiation; should be invoked before run a job
job_init()
{
	export TMP=/tmp/lkp
	mkdir -p $TMP
	rm -fr $TMP/*

	cp /proc/uptime $TMP/boot-time

	job_redirect_stdout_stderr
}
