# common utility functions

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
