#!/bin/sh

. $LKP_SRC/lib/env.sh

do_wipefs()
{
	local dev=$1
	local usage

	usage=$(wipefs -h 2>/dev/null) || {
		log_cmd dd if=/dev/zero of=$dev bs=4k count=100 status=noxfer
		return
	}

	if [ "${usage#*--force}" != "$usage" ]; then
		log_cmd wipefs -a --force $dev
	else
		log_cmd wipefs -a $dev
	fi
}

remove_dm()
{
	[ -n "$nr_partitions" ] || return
	has_cmd dmsetup || return

	log_cmd dmsetup remove_all
}

destroy_fs()
{
	for dev in $partitions
	do
		do_wipefs $dev
	done
}

destroy_devices()
{
	remove_dm
	destroy_fs
}

