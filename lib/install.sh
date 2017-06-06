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
	opensuse)
		zypper update ;;
	*) echo "Not support $distro to do update" ;;
	esac
}

adapt_package()
{
	local pkg_name=$1
	local distro_file=$2
	[ -z "$distro_file" ] && return 1
	[ -f "$distro_file" ] || return 1
	grep "^$pkg_name:" $distro_file
}

# To adapt packages between distributions, use Debian as the default distribution.
# There are two kinds of packages, packages provided by distribution and packages installed by makepkg
# The priority for package adaptation is as follow:
# - adaptation by makepkg, via $LKP_SRC/distro/adaptation-pkg/$distro
# - adaptation by distro explicitly, via $LKP_SRC/distro/adaptation/$distro
# - default to input package name, not found in above
adapt_packages()
{
	local distro_file
	if [ -z "$PKG_TYPE" ]; then
		distro_file="$LKP_SRC/distro/adaptation/$distro"
		makepkg_distro_file="$LKP_SRC/distro/adaptation-pkg/$distro"
	else
		distro_file="$LKP_SRC/distro/adaptation-$PKG_TYPE/$distro"
	fi

	local distro_pkg=

	for pkg in $generic_packages
	do
		local mapping=""
		local is_arch_dep="$(echo $pkg | grep ":")"
		if [ -n "$is_arch_dep" ]; then
			mapping="$(adapt_package $pkg $distro_file | tail -1)"
		else
			mapping="$(adapt_package $pkg $distro_file | head -1)"
		fi
		if [ -n "$mapping" ]; then
			distro_pkg=$(echo $mapping | awk -F": " '{print $2}')
			if [ -n "$distro_pkg" ]; then
				echo $distro_pkg
			else
				distro_pkg=${mapping%%::*}
				[ "$mapping" != "$distro_pkg" ] && [ -n "$distro_pkg" ] && echo $distro_pkg
			fi
		else
			[ -z "$PKG_TYPE" ] && ! adapt_package $pkg $makepkg_distro_file >/dev/null && echo $pkg
		fi
	done
}

get_dependency_packages()
{
	local distro=$1
	local script=$2
	local PKG_TYPE=$3
	local base_file="$LKP_SRC/distro/depends/${script}"

	[ -f "$base_file" ] || return

	local generic_packages="$(sed 's/#.*//' "$base_file")"

	adapt_packages | sort | uniq
}

get_build_dir()
{
	echo "/tmp/build-$1"
}
