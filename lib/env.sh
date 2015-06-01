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
	# $node_roles will be determined at job schedule time and
	# set accordingly in each scheduled job
	local __my_roles=" $node_roles "

	[ "${__my_roles#* $1 }" != "$__my_roles" ]
}

is_virt()
{
	if has_cmd 'virt-what'; then
		[ "$(virt-what)" = "kvm" ]
	else
		grep -q -w hypervisor /proc/cpuinfo
	fi
}
