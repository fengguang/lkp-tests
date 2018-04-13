# common utility functions

. $LKP_SRC/lib/debug.sh

is_abs_path()
{
	[[ "${1:0:1}" = "/" ]]
}

abs_path()
{
	local path="$1"
	if is_abs_path $path; then
		echo $path
	else
		echo $PWD/$path
	fi
}

query_var_from_yaml()
{
	local key=$1
	local yaml_file=${2:--}
	[ $# -ge 1 ] || die "Invalid parmeters: $*"

	sed -ne "1,\$s/^$key[[:space:]]*:[[:space:]]*\\(.*\\)[[:space:]]*\$/\\1/p" "$yaml_file"
}

# the followings are false, otherwise true
# - null string
# - string starts with 0
# - no
# - false
# - n
parse_bool()
{
	if [ "$1" != "-q" ]; then
		otrue=1
		ofalse=0
	else
		shift
	fi
	[ -z "$1" ] && { echo $ofalse; return 1; }
	[ "${1#0}" != "$1" ] && { echo $ofalse; return 1; }
	[ "${1#no}" != "$1" ] && { echo $ofalse; return 1; }
	[ "${1#false}" != "$1" ] && { echo $ofalse; return 1; }
	[ "${1#n}" != "$1" ] && { echo $ofalse; return 1; }
	echo $otrue; return 0
}

expand_cpu_list()
{
	cpu_list=$1
	for pair in $(echo "$cpu_list" | tr ',' ' '); do
		if [ "${pair%%-*}" != "$pair" ]; then
			seq $(echo "$pair" | tr '-' ' ')
		else
			echo "$pair"
		fi
	done
}

is_rt()
{
	local path=$1
	local bn=$(basename "$path")
	local dn=$(dirname "$path")
	[[ $bn =~ ^[0-9]{1,5}$ ]] &&
		[[ -f "$path/job.yaml" ]] &&
		[[ -f "$dn/stddev.json" ]]
}
