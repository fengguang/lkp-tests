#!/bin/sh

is_local_server()
{
	[ "$LKP_SERVER" != "${LKP_SERVER#inn}" ] && return
	[ "$LKP_SERVER" != "${LKP_SERVER#192.168.}" ] && return
	return 1
}

upload_files()
{
	local files
	local file
	local ret=0

	[ $# -ne 0 ] || return

	if has_cmd rsync && is_local_server; then
		rsync -a --ignore-missing-args --min-size=1 "$@" rsync://$LKP_SERVER$JOB_RESULT_ROOT/
	elif has_cmd curl; then
		files=$(find "$@" -type f -size +0 2>/dev/null)
		[ -n "$files" ] || return

		for file in $files
		do
			curl -T $file http://$LKP_SERVER$JOB_RESULT_ROOT/ || ret=$?
		done
		return $ret
	else
		# NFS is the last resort -- it seems unreliable, either some
		# content has not reached NFS server during post processing, or
		# some files occasionally contain some few '\0' bytes.

		chown -R lkp.lkp "$@"
		chmod -R  ug+w "$@"
		cp -a "$@" $RESULT_ROOT/ || {
			ls -l "$@" $RESULT_ROOT 2>&1
			return 1
		}
	fi
}

