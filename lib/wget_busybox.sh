#!/bin/sh

setup_wget_busybox()
{
	local busybox

	busybox=$(cmd_path busybox) || return

	http_client_cmd="$busybox wget -q"
}

[ -n "$http_client_cmd" ] || setup_wget_busybox || return

. $LKP_SRC/lib/wget.sh

http_get_newer()
{
	http_get_newer_can_skip "$@" && return
	http_get_file "$@"
}
