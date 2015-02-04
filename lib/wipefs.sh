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

destroy_devices() {
	for dev in $partitions
	do
		do_wipefs $dev
	done
}

