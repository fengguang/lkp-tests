#!/bin/sh

is_local_server()
{
	[ "$LKP_SERVER" != "${LKP_SERVER#inn}" ] && return
	[ "$LKP_SERVER" != "${LKP_SERVER#192.168.}" ] && return
	return 1
}

upload_files()
{
	local file
	local ret=0

	if has_cmd rsync && is_local_server; then
		rsync -a --ignore-missing-args --min-size=1 "$@" rsync://$LKP_SERVER$JOB_RESULT_ROOT/
	elif has_cmd curl; then
		for file
		do
			[ -s "$file" ] || continue
			curl -T $file http://$LKP_SERVER$JOB_RESULT_ROOT/ || ret=$?
		done
		return $ret
	else
		# NFS is the last resort -- it seems unreliable, either some
		# content has not reached NFS server during post processing, or
		# some files occasionally contain some few '\0' bytes.
		for file
		do
			[ -s "$file" ] || continue
			chown lkp.lkp "$file"
			chmod ug+w    "$file"
			cp -p "$file" $RESULT_ROOT/ || ret=$?
		done
		[ "$ret" -ne 0 ] && ls -l "$@" $RESULT_ROOT 2>&1
		return $ret
	fi
}

