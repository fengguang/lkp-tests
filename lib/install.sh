#!/bin/sh

get_dependency_packages()
{
	local distro=$1
	local script=$2
	local file="$LKP_SRC/distro/$distro/${script}"

	[ -f "$file" ] || return

	sed 's/#.*//' "$file"
}

