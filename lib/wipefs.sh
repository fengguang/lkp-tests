#!/bin/sh

do_wipefs()
{
	local dev=$1
	local usage

	usage=$(wipefs -h 2>/dev/null) || {
		dd if=/dev/zero of=$dev bs=4k count=100 status=noxfer
		return
	}

	if [ "${usage#*--force}" != "$usage" ]; then
		wipefs -a --force $dev
	else
		wipefs -a $dev
	fi
}

remove_dm()
{
	[ -n "$nr_partitions" ] || return
	command -v dmsetup >/dev/null || return

	dmsetup remove_all
}

destroy_devices()
{
	remove_dm

	for dev in $partitions
	do
		do_wipefs $dev
	done
}

