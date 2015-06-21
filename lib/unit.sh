#!/bin/bash

export_meminfo()
{
	local key val unit

	while read key val unit
	do
		key="${key%%:}"
		key="${key%%)}"
		[ "${key#*(}" != "$key" ] &&
		key="${key%(*}_${key#*(}"
		export "$key=$val"
	done < /proc/meminfo
}

to_byte()
{
	local s=$1
	local size="${s%%[a-zA-Z]*}"
	local unit="${s##*[0-9]}"

	[ "$size" = "$s" ] && {
		echo "$s"
		return
	}

	case $unit in
		PB|pb|P|p)
			echo $((size << 50))
			;;
		TB|tb|T|t)
			echo $((size << 40))
			;;
		GB|gb|G|g)
			echo $((size << 30))
			;;
		MB|mb|M|m)
			echo $((size << 20))
			;;
		KB|kb|K|k)
			echo $((size << 10))
			;;
		B|b)
			echo $size
			;;
	esac
}

to_kb()
{
	local bytes
	bytes=$(to_byte "$1")
	echo $((bytes >> 10))
}

to_mb()
{
	local bytes
	bytes=$(to_byte "$1")
	echo $((bytes >> 20))
}

to_gb()
{
	local bytes
	bytes=$(to_byte "$1")
	echo $((bytes >> 30))
}
