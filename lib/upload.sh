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
	[ -n "$target_directory" ] && {

		local current_dir=$(pwd)
		local tmpdir=$(mktemp -d)
		cd "$tmpdir"
		mkdir -p ${target_directory}

		rsync -a --no-owner --no-group \
			--chmod=D775,F664 \
			--ignore-missing-args \
			--min-size=1 \
			${target_directory%%/*} rsync://$LKP_SERVER$JOB_RESULT_ROOT/

		local JOB_RESULT_ROOT=$JOB_RESULT_ROOT/$target_directory

		cd $current_dir
		rm -fr "$tmpdir"
	}

	rsync -a --no-owner --no-group \
		--chmod=D775,F664 \
		--ignore-missing-args \
		--min-size=1 \
		"$@" rsync://$LKP_SERVER$JOB_RESULT_ROOT/
}

upload_files_lftp()
{
	local file
	local dest_file
	local ret=0
	local LFTP_TIMEOUT='set net:timeout 2; set net:reconnect-interval-base 2; set net:max-retries 2;'
	local UPLOAD_HOST="http://$LKP_SERVER"

	[ -n "$target_directory" ] && {
		local JOB_RESULT_ROOT=$JOB_RESULT_ROOT/$target_directory
		lftp -c "$LFTP_TIMEOUT; open '$UPLOAD_HOST'; mkdir -p '$JOB_RESULT_ROOT'"
	}

	for file
	do
		if [ -d "$file" ]; then
			[ "$(ls -A $file)" ] && lftp -c "$LFTP_TIMEOUT; open '$UPLOAD_HOST'; mirror -R '$file' '$JOB_RESULT_ROOT/'" || ret=$?
		else
			[ -s "$file" ] || continue
			dest_file=$JOB_RESULT_ROOT/$(basename $file)

			lftp -c "$LFTP_TIMEOUT; open '$UPLOAD_HOST'; put -c '$file' -o '$dest_file'" || ret=$?
		fi
	done

	return $ret
}

upload_one_curl()
{
	if [ -d "$1" ]; then
		(
			cd $(dirname "$1")
			dir=$(basename "$1")
			find "$dir" -type d -exec curl -X MKCOL 'http://$LKP_SERVER$JOB_RESULT_ROOT/{}' \;
			find "$dir" -type f -size +0 -exec curl -T '{}' 'http://$LKP_SERVER$JOB_RESULT_ROOT/{}' \;
		)
	else
		[ -s "$file" ] || return
		curl -T "$file" http://$LKP_SERVER$JOB_RESULT_ROOT/
	fi
}

upload_files_curl()
{
	local file
	local ret=0

	[ -n "$target_directory" ] && {

		local dir
		for dir in $(echo $target_directory | tr '/' ' ')
		do
			local JOB_RESULT_ROOT=$JOB_RESULT_ROOT/$dir
			curl -X MKCOL http://$LKP_SERVER$JOB_RESULT_ROOT
		done
	}

	for file
	do
		upload_one_curl "$file" || ret=$?
	done

	return $ret
}

upload_files_copy()
{
	[ -n "$target_directory" ] && {
		local RESULT_ROOT="$RESULT_ROOT/$target_directory"

		mkdir -p $RESULT_ROOT
		chown -R lkp.lkp $RESULT_ROOT
		chmod -R g+w $RESULT_ROOT
	}

	chown -R lkp.lkp "$@"
	chmod -R ug+w "$@"

	local file
	local ret=0

	for file
	do
		[ -s "$file" ] || continue
		cp -a "$file" $RESULT_ROOT/ || {
			ls -l "$@" $RESULT_ROOT 2>&1
			ret=$?
		}
	done

	return $ret
}

upload_files()
{
	if [ "$1" = "-t" ]; then
		local target_directory="$2"

		shift 2
	fi

	[ $# -ne 0 ] || return

	if [ -z "$NO_NETWORK" ] && [ "$result_service" = "${result_service#9p/}" ]; then
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
		fi
	else
		# NFS is the last resort -- it seems unreliable, either some
		# content has not reached NFS server during post processing, or
		# some files occasionally contain some few '\0' bytes.
		upload_files_copy "$@"
		return
	fi
}
