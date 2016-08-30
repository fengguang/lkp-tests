#!/bin/sh

[ -n "$lib_env_load_once" ] && return
lib_env_load_once=1

[ -n "$LKP_SRC" ] || LKP_SRC=$(dirname $(dirname $(readlink -e -v $0)))

if command -v command >/dev/null 2>&1; then
	has_cmd()
	{
		command -v "$1" >/dev/null
	}

	cmd_path()
	{
		command -v "$1"
	}
else
	has_cmd()
	{
		type "$1" >/dev/null 2>&1
	}

	cmd_path()
	{
		has_cmd "$1" && which "$1"
	}
fi

nproc()
{
	if has_cmd 'nproc'; then
		/usr/bin/nproc
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
	if [ -n "$model" ]; then
		# running inside LKP job
		[ -n "$nr_vm" ]
	elif has_cmd 'virt-what'; then
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
		perf=$(cmd_path perf) || {
			. $LKP_SRC/lib/debug.sh
			die "Can not find perf command"
		}
	fi
}
