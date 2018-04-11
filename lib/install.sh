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
	oracle) yum update ;;
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

remove_packages_version()
{
	generic_packages=$(echo $generic_packages | sed 's/=.*//')
}

get_dependency_packages()
{
	local distro=$1
	local script=$2
	local PKG_TYPE=$3
	local base_file="$LKP_SRC/distro/depends/${script}"

	[ -f "$base_file" ] || return

	local generic_packages="$(sed 's/#.*//' "$base_file")"
	[ "$distro" != "debian" ] && remove_packages_version

	adapt_packages | sort | uniq
}

get_build_dir()
{
	echo "/tmp/build-$1"
}

download_distro_depends() {
	local script=$1
	local dest=$2
	local pkg
	local pkg_dir

	if [ -z "$BM_NAME" ]; then
		BM_NAME="$script"
		unset_bmname=1
	fi

	local debs=$(get_dependency_packages $DISTRO $script)
	resolve_depends "$debs"
	if [ -n "$PACKAGE_VERSION_LIST" ]; then
		(
			cd "$dest"
			download "$PACKAGE_VERSION_LIST"
			save_package_deps_info $BM_NAME
			echo "$PACKAGE_LIST" >> $pack_to/.${BM_NAME}.packages
		)
	fi
	# install the dependencies to build pkg
	$LKP_SRC/distro/installer/$DISTRO $debs

	local packages="$(get_dependency_packages ${DISTRO} ${script} pkg)"
	if [ -z "$packages" ] || [ "$packages" = " " ]; then
			return 0
	fi

	for pkg in $packages; do
		download_distro_depends $pkg "$dest"
	done

	if [ "$BM_NAME" = "$script" ] && [ -n "$unset_bmname" ]; then
		unset BM_NAME
		unset unset_bmname
	fi
}

build_depends_pkg() {
	if [ "$1" = '-i' ]; then
		# in recursion install the package with -i option
		local INSTALL='-i'
		shift
	else
		# only pack the package
		local INSTALL='--noarchive'
	fi
	local script=$1
	local dest=$2
	local pkg
	local pkg_dir

	if [ -z "$BM_NAME" ]; then
		BM_NAME="$script"
		unset_bmname=1
	fi

	local debs=$(get_dependency_packages $DISTRO ${script}-dev)
	# install the dev dependencies to build pkg
	$LKP_SRC/distro/installer/$DISTRO $debs

	local packages="$(get_dependency_packages ${DISTRO} ${script} pkg)"
	local dev_packages="$(get_dependency_packages ${DISTRO} ${script}-dev pkg)"
	packages="$(echo $packages $dev_packages | tr '\n' ' ')"
	if [ -z "$packages" ] || [ "$packages" = " " ]; then
		if [ "$BM_NAME" = "$script" ] && [ -z "$PACKAGE_LIST" ]; then
			echo "empty deps for $BM_NAME"
			return 1
		else
			return 0
		fi
	fi
	
	for pkg in $packages; do
		# pack and install dependencies of pkg
		build_depends_pkg -i $pkg "$dest"
		pkg_dir="$LKP_SRC/pkg/$pkg"
		if [ -d "$pkg_dir" ]; then
			(
				cd "$pkg_dir" && \
				PACMAN="$LKP_SRC/sbin/pacman-LKP" "$LKP_SRC/sbin/makepkg" $INSTALL --config "$LKP_SRC/etc/makepkg.conf" --skippgpcheck
				cp -rf "$pkg_dir/pkg/$pkg"/* "$dest"
				rm -rf "$pkg_dir/"{src,pkg}
			)
		fi
	done

	if [ "$BM_NAME" = "$script" ] && [ -n "$unset_bmname" ]; then
		unset BM_NAME
		unset unset_bmname
	fi
}
