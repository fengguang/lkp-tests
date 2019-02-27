#!/bin/sh

setup_wget()
{
	local wget
	wget=$(cmd_path wget) || return

	# wget command may link to busybox which not support --local-encoding
	# etc. options
	[ -L "$wget" ] && return 1

	http_client_cmd="$wget -q --timeout=1800 --tries=1"

	local wget_help="$($http_client_cmd --help 2>&1)"

	[ "$wget_help" != "${wget_help#*--local-encoding}" ] && {
		local iri_not_support="This version does not have support for IRIs"
		# $ /usr/bin/wget --local-encoding=UTF-8 /tmp/abcde
		# This version does not have support for IRIs
		$http_client_cmd --local-encoding=UTF-8 /tmp/abcde 2>&1 | grep -qF "$iri_not_support" || http_client_cmd="$http_client_cmd --local-encoding=UTF-8"
	}

	return 0
}

[ -n "$http_client_cmd" ] || setup_wget || return

http_get_file()
{
	check_create_base_dir "$2"
	http_do_request "$1" -O "$2"
}

http_get_directory()
{
	local dir=$2
	mkdir -p $dir
	# download directory recursively
	http_do_request "$1" -c -r -np -nd -P "$dir"
}

http_get_newer()
{
	local path="$(dirname "$2")"
	http_do_request "$1" -N -P "$path"
}

http_get_cgi()
{
	check_create_base_dir "$2"
	http_do_request "$1" -O "${2:-/dev/null}"
}
