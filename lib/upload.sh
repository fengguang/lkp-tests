#!/bin/sh

. $LKP_SRC/lib/env.sh

is_local_server()
{
	[ "$LKP_SERVER" != "${LKP_SERVER#inn}" ] && return
	[ "$LKP_SERVER" != "${LKP_SERVER#192.168.}" ] && return
	return 1
}

upload_files_rsync()
{
	rsync -a --ignore-missing-args --min-size=1 "$@" rsync://$LKP_SERVER$JOB_RESULT_ROOT/
}

upload_files_lftp()
{
	local file
	local dest_file
	local dest_path
	local ret=0
	local LFTP_TIMEOUT='set net:timeout 2; set net:reconnect-interval-base 2; set net:max-retries 2;'

	for file
	do
		if [[ -d "$file" ]]; then
			[[ "$(ls -A $file)" ]] && lftp -c "$LFTP_TIMEOUT; open '$LKP_SERVER'; mirror -R '$file' '$JOB_RESULT_ROOT/'" || ret=$?
		else
			[[ -s "$file" ]] || continue
			dest_path=$(dirname "$file")
			dest_file=$JOB_RESULT_ROOT/$file

			lftp -c "$LFTP_TIMEOUT; open '$LKP_SERVER'; mkdir -p '$dest_path'; put -c '$file' -o '$dest_file'" || ret=$?
		fi
	done

	return $ret
}

upload_files_curl()
{
	local file
	local files
	local dir
	local dirs
	local ret=0

	dirs=$(find "$@" -type d 2>/dev/null)

	for dir in $dirs
	do
		curl -X MKCOL http://$LKP_SERVER$JOB_RESULT_ROOT/$dir
	done

	files=$(find "$@" -type f -size +0 2>/dev/null)
	[ -n "$files" ] || return

	for file in $files
	do
		curl -T "$file" http://$LKP_SERVER$JOB_RESULT_ROOT/$file || ret=$?
	done

	return $ret
}

upload_files_copy()
{
	local file
	local ret=0

	for file
	do
		test -s "$file" || continue
		upload_copy_one "$file" || ret=$?
	done

	return $ret
}

upload_copy_one()
{
	chown -R lkp.lkp "$@"
	chmod -R ug+w "$@"

	cp -a "$@" $RESULT_ROOT/ && return

	ls -l "$@" $RESULT_ROOT 2>&1
	return 1
}

upload_files()
{
	[ $# -ne 0 ] || return

	if has_cmd rsync && is_local_server; then
		upload_files_rsync "$@"
		return
	fi

	if has_cmd lftp; then
		upload_files_lftp "$@"
		return
	fi

	if has_cmd curl; then
		upload_files_curl "$@"
		return
	else
		# NFS is the last resort -- it seems unreliable, either some
		# content has not reached NFS server during post processing, or
		# some files occasionally contain some few '\0' bytes.
		upload_files_copy "$@"
		return
	fi
}
