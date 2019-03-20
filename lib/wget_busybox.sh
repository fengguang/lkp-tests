#!/bin/sh

setup_wget_busybox()
{
	wget=$(cmd_path wget)
	http_client_cmd="$wget -q"
}

[ -n "$http_client_cmd" ] || setup_wget_busybox || return

. $LKP_SRC/lib/wget.sh

http_get_file()
{
	check_create_base_dir "$2"
	http_escape_request "$1" -O "$2"
}

http_get_newer()
{
	http_get_newer_can_skip "$@" && return
	http_get_file "$@"
}
