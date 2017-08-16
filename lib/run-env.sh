#!/bin/sh

__local_run()
{
	host_name=$(hostname)
	host_file="$LKP_SRC/hosts/$host_name"
	if [ -f "$host_file" ] && grep -sq '^local_run:[[:space:]]*1' "$host_file"; then
		echo 1
	else
		echo 0
	fi
}

local_run()
{
	if ! [ "$LKP_LOCAL_RUN" = 1 ] && ! [ "$LKP_LOCAL_RUN" = 0 ]; then
		export LKP_LOCAL_RUN=$(__local_run)
	fi
	[ "$LKP_LOCAL_RUN" = 1 ]
}

result_prefix()
{
	_result_prefix=${RESULT_PREFIX-null_prefix}
	if [ "$_result_prefix" = null_prefix ]; then
		if local_run; then
			RESULT_PREFIX=/lkp
		else
			RESULT_PREFIX=
		fi
		export RESULT_PREFIX
	fi
	echo "$RESULT_PREFIX"
}

git_root_dir()
{
	_git_root_dir=${GIT_ROOT_DIR-null_dir}
	if [ "$_git_root_dir" = null_dir ]; then
		if local_run; then
			GIT_ROOT_DIR=/lkp/repo
		else
			GIT_ROOT_DIR=/c/repo
		fi
		export GIT_ROOT_DIR
	fi
	echo "$GIT_ROOT_DIR"
}

set_local_run()
{
	LKP_LOCAL_RUN=1
}
