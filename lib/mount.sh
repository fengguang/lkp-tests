#!/bin/sh

is_mount_point()
{
	if command -v mountpoint >/dev/null; then
		mountpoint -q $1
	else
		grep -q -F " $1 " /proc/mounts
	fi
}

check_mount()
{
	local dev=$1
	local mnt=$2

	[ "${dev#-}" = "$dev" ] || {
		echo "check_mount $*: please put options in the end" >&2
		return
	}

	is_mount_point $2 && return
	mkdir -p $2
	mount $* && return

	# debug mount failure
	local exit_code=$?
	echo "mount $*"
	mount
	cat /proc/filesystems
	return $exit_code
}

