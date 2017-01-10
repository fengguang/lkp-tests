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

http_get_directory()
{
	local dir=$2
	local path=$1
	local file_list
	mkdir -p $dir

	# <tr><td valign="top"><img src="/icons/unknown.gif" alt="[    ]"></td><td><a href="0f-00-0a">0f-00-0a</a></td><td align="right">2016-12-26 16:44  </td><td align="right">6.0K</td><td>&nbsp;</td></tr>
	# <tr><td valign="top"><img src="/icons/unknown.gif" alt="[    ]"></td><td><a href="0f-00-07">0f-00-07</a></td><td align="right">2016-12-26 16:44  </td><td align="right">4.0K</td><td>&nbsp;</td></tr>
	# <tr><td valign="top"><img src="/icons/unknown.gif" alt="[    ]"></td><td><a href="0f-01-02">0f-01-02</a></td><td align="right">2016-12-26 16:44  </td><td align="right">2.0K</td><td>&nbsp;</td></tr>
	# <tr><td valign="top"><img src="/icons/unknown.gif" alt="[    ]"></td><td><a href="0f-02-04">0f-02-04</a></td><td align="right">2016-12-26 16:44  </td><td align="right">6.0K</td><td>&nbsp;</td></tr>
	# <tr><td valign="top"><img src="/icons/unknown.gif" alt="[    ]"></td><td><a href="0f-02-05">0f-02-05</a></td><td align="right">2016-12-26 16:44  </td><td align="right">8.0K</td><td>&nbsp;</td></tr>
	# <tr><td valign="top"><img src="/icons/unknown.gif" alt="[    ]"></td><td><a href="0f-02-06">0f-02-06</a></td><td align="right">2016-12-26 16:44  </td><td align="right">2.0K</td><td>&nbsp;</td></tr>
	dir_page_content=$(http_do_request $path)
	if [ -z "$dir_page_content" ]; then
		echo "Failed to get directory page"
		return 1
	fi

	file_list=$(echo "$dir_page_content" | grep href | sed -e 's/.*href="//' -e 's/".*//' | grep -v '/')
	# download first level files in the given directory
	for file in $file_list; do
		http_do_request $path/$file -o $dir/$file || {
			echo "Failed to download file: $file"
			return 1
		}
	done
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
