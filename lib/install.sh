#!/bin/sh

. $LKP_SRC/lib/detect-system.sh

sync_distro_sources()
{
	detect_system
	distro=$_system_name_lowercase
	distro_version=$_system_version

	case $distro in
	debian|ubuntu) apt-get update ;;
	fedora)
		if [ $distro_version -ge 22 ]; then
			dnf update
		else
			yum update
		fi ;;
	archlinux) yaourt -Sy ;;
	*) echo "Not support $distro to do update" ;;
	esac
}

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
		local mapping="$(grep "^$pkg:" $distro_file)"
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

	local generic_packages="$(sed 's/#.*//' "$base_file")"

	adapt_packages
}
