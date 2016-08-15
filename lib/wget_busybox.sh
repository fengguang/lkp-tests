#!/bin/sh

setup_wget_busybox()
{
	local busybox

	busybox=$(command -v busybox) || return

	http_client_cmd="$busybox wget -q"
}

[ -n "$http_client_cmd" ] || setup_wget_busybox || return

. $LKP_SRC/lib/wget.sh

http_get_newer()
{
	# versioned files can be safely cached without checking timestamp
	[ "${1#*-????-??-??}" != "$1" ] &&
	[ -s "$2" ] && return

	http_get_file "$@"
}
