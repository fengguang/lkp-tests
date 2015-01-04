#!/bin/sh

role()
{
	# $host_roles will be determined at job schedule time and
	# set accordingly in each scheduled job
	local __my_host_rules=" $host_roles "

	[ "${__my_host_rules#* $1 }" != "$__my_host_rules" ]
}

