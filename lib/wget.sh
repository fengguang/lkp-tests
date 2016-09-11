#!/bin/sh

setup_wget()
{
	local wget
	wget=$(cmd_path wget) || return

	# wget command may link to busybox which not support --local-encoding
	# etc. options
	[ -L "$wget" ] && return 1

	http_client_cmd="$wget -q"

	local wget_help="$($http_client_cmd --help 2>&1)"

	[ "$wget_help" != "${wget_help#*--local-encoding}" ] &&
	http_client_cmd="$http_client_cmd --local-encoding=UTF-8"

	[ "$wget_help" != "${wget_help#*--retry-connrefused}" ] &&
	http_client_cmd="$http_client_cmd --retry-connrefused --waitretry 1000 --tries 1000"

	return 0
}

[ -n "$http_client_cmd" ] || setup_wget || return

http_get_file()
{
	local path="$(dirname "$2")"
	[ -d "$path" ] || mkdir -p "$path"

	http_do_request "$1" -O "$2"
}

http_get_newer()
{
	local path="$(dirname "$2")"
	http_do_request "$1" -N -P "$path"
}

http_get_cgi()
{
	http_do_request "$1" -O "${2:-/dev/null}"
}
