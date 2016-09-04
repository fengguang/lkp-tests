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
		return $?
	fi

	files=$(find "$@" -type f -size +0 2>/dev/null)
	[ -n "$files" ] || return

	if has_cmd curl; then
		for file in $files
		do
			curl -T $file http://$LKP_SERVER$JOB_RESULT_ROOT/$file || ret=$?
		done
		return $ret
	else
		# NFS is the last resort -- it seems unreliable, either some
		# content has not reached NFS server during post processing, or
		# some files occasionally contain some few '\0' bytes.

		chown -R lkp.lkp $files
		chmod -R  ug+w $files
		cp -a $files $RESULT_ROOT/ || {
			ls -l $files $RESULT_ROOT 2>&1
			return 1
		}
	fi
}

