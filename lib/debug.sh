#!/bin/sh

dump_call_stack()
{
	[ -n "$BASHPID" ] || return

	local stack_depth=${#FUNCNAME[@]}
	local i
	for i in $(seq 0 $stack_depth); do
		[[ $i -eq $stack_depth ]] && break
		echo "  ${BASH_SOURCE[i+1]}:${BASH_LINENO[i]}: ${FUNCNAME[i+1]}" >&2
	done
}

die()
{
	echo "$@" 1>&2
	dump_call_stack
	exit 1
}
