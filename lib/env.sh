#!/bin/sh

[ -n "$LKP_SRC" ] || LKP_SRC=$(dirname $(dirname $(readlink -e -v $0)))
. $LKP_SRC/lib/debug.sh

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
		# run as root
		[ -n "$(virt-what)" ]
	else
		grep -q -w hypervisor /proc/cpuinfo
	fi
}

set_perf_path()
{
	if [ -x "$1" ]; then
		perf="$1"
	else
		perf=$(command -v perf) || die "Can not find perf command"
	fi
}
