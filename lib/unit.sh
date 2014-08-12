#!/bin/bash

to_byte()
{
	[[ "$1" =~ ^([0-9]+)([bBkKmMgGtTpP]) ]] || {
		echo "$1" | grep -o '^[0-9]*'
		return
	}

	local size=${BASH_REMATCH[1]}
	local unit=${BASH_REMATCH[2]}

	case $unit in
		P|p)
			echo $((size << 50))
			;;
		T|t)
			echo $((size << 40))
			;;
		G|g)
			echo $((size << 30))
			;;
		M|m)
			echo $((size << 20))
			;;
		K|k)
			echo $((size << 10))
			;;
		B|b)
			echo $size
			;;
	esac
}

to_kb()
{
	local bytes=$(to_byte "$1")
	echo $((bytes >> 10))
}

to_mb()
{
	local bytes=$(to_byte "$1")
	echo $((bytes >> 20))
}

to_gb()
{
	local bytes=$(to_byte "$1")
	echo $((bytes >> 30))
}
