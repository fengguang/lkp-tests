#!/bin/sh

setup_curl()
{
	http_client_cmd=$(command -v curl) || return
	http_client_cmd="$http_client_cmd -s"
}

[ -n "$http_client_cmd" ] || setup_curl || return

http_get_file()
{
	http_do_request "$1" -o "$2"
}

http_get_newer()
{
	if [ -s "$2" ]; then
		http_do_request "$1" -o "$2" -z "$2"
	else
		http_do_request "$1" -o "$2"
	fi
}

http_get_cgi()
{
	http_do_request "$1" -o /dev/null
}
