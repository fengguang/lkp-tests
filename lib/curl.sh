#!/bin/sh

setup_curl()
{
	http_client_cmd=$(cmd_path curl) || return
	http_client_cmd="$http_client_cmd -sSf"
}

[ -n "$http_client_cmd" ] || setup_curl || return

http_get_file()
{
	check_create_base_dir "$2"
	http_escape_request "$1" -o "$2"
}

http_get_newer()
{
	check_create_base_dir "$2"

	if [ -s "$2" ]; then
		http_escape_request "$1" -o "$2" -z "$2"
	else
		http_escape_request "$1" -o "$2"
	fi
}

http_get_cgi()
{
	check_create_base_dir "$2"
	http_do_request "$1" -o "${2:-/dev/null}"
}
