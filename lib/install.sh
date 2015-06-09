#!/bin/sh

adapt_packages()
{
	local distro_file="$LKP_SRC/distro/adaptation/$distro"
	[ -f "$distro_file" ] || {
		echo $generic_packages
		return
	}

	local distro_pkg=

	for pkg in $generic_packages
	do
		local mapping=$(grep -q "^$pkg:" $distro_file)
		if [ -n "$mapping" ]; then
			distro_pkg=${mapping#$pkg:}
			[ -n "$distro_pkg" ] && echo $distro_pkg
		else
			echo $pkg
		fi
	done
}

get_dependency_packages()
{
	local distro=$1
	local script=$2
	local base_file="$LKP_SRC/distro/depends/${script}"

	[ -f "$base_file" ] || return

	local generic_packages=$(sed 's/#.*//' "$base_file")

	adapt_packages
}
