#!/bin/sh

has_cmd()
{
	command -v "$1" >/dev/null
}

nproc()
{
	if has_cmd 'nproc'; then
		command 'nproc'
	elif has_cmd 'getconf'; then
		getconf '_NPROCESSORS_CONF'
	else
		grep -c '^processor' /proc/cpuinfo
	fi
}

role()
{
	# $host_roles will be determined at job schedule time and
	# set accordingly in each scheduled job
	local __my_host_rules=" $host_roles "

	[ "${__my_host_rules#* $1 }" != "$__my_host_rules" ]
}

