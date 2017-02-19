#!/bin/bash
#
# linux kernel CROSS make wrapper
#
# It will download/unpack the cross tool chain if necessary,
# then invoke make with suitable options.
#
# It detects ARCH in 4 ways.
#
# - make.i386 # make it a symlink to this script
# - make.cross ARCH=i386
# - cd obj-i386; make.cross
# - export ARCH=i386; make.cross
#
# Copyright (c) 2014, Intel Corporation.
# Author: Fengguang Wu <fengguang.wu@intel.com>
# Credit: Tony Breeds <tony@bakeyournoodle.com> for crosstool

GCC_INSTALL_PATH=/opt

if [[ ! "$0" =~ 'make.cross' && "$0" =~ make\.([a-z0-9_]+) ]]; then
	export ARCH="${BASH_REMATCH[1]}"
elif [[ "$*" =~ ARCH=([a-z0-9_]+) ]]; then
	export ARCH="${BASH_REMATCH[1]}"
elif [[ ${PWD##*-} =~ ^(i386|x86_64|alpha|arm|arm64|avr32|blackfin|c6x|cris|frv|h8300|hexagon|ia64|m32r|m68k|microblaze|mips|mn10300|openrisc|parisc|powerpc|s390|score|sh|sh64|sparc|sparc32|sparc64|tile|tilepro|tilegx|um|unicore32|xtensa)$ ]]; then
	export ARCH=${PWD##*-}
elif [[ ! $ARCH ]]; then
	export ARCH=x86_64
fi

[[ "$*" =~ ARCH=([a-z0-9_]+) ]] && [[ $ARCH != ${BASH_REMATCH[1]} ]] && {
	echo "Conflicting ARCH specified! $ARCH ${BASH_REMATCH[1]}"
	exit 1
}

shopt -s nullglob

install_packages()
{
	[[ ! -x /usr/bin/xz || ! -x /usr/bin/lftp ]] && {
		if [[ -x /usr/bin/apt-get ]]; then
			echo apt-get install xz-utils lftp
			sudo apt-get install xz-utils lftp
		else
			echo Please install: xz-utils lftp
			exit 1
		fi
	}
}

download_extract()
{
	local URL="$1"

	echo lftpget -c $URL
	     lftpget -c $URL

	local file="$(basename $URL)"
	echo tar Jxf $file -C $GCC_INSTALL_PATH
	sudo tar Jxf $file -C $GCC_INSTALL_PATH
}

install_crosstool()
{
	local URL=https://cdn.kernel.org/pub/tools/crosstool/files/bin
	local list=/tmp/crosstool-files

	[[ -s $list ]] || {
		local os_bit="$(getconf LONG_BIT)"

		if [[ $os_bit = 32 ]]; then
			local os_arch=i686
		else
			local os_arch=x86_64
		fi

		lftp -c "open $URL && find $os_arch > $list" || exit
	}

	local file
	file=$(grep "${gcc_arch}.*\.tar\.xz" $list | tail -1)
	[[ $file ]] || {
		echo "Cannot find $gcc_arch under $URL check $list"
		exit 1
	}

	download_extract "$URL/$file"
}

install_linaro()
{
	local URL='http://releases.linaro.org/archive/14.08/components/toolchain/binaries'
	local file='gcc-linaro-aarch64-linux-gnu-4.9-2014.08_linux.tar.xz'

	download_extract "$URL/$file"

	local dir="$GCC_INSTALL_PATH/$(basename $file .tar.xz)"
	local cross_gcc_version=($dir/bin/${gcc_arch}-gcc-*.*.*)
	local cross_gcc_version=${cross_gcc_version##*-}

	echo mkdir -p $GCC_INSTALL_PATH/gcc-$cross_gcc_version
	sudo mkdir -p $GCC_INSTALL_PATH/gcc-$cross_gcc_version
	echo mv $dir  $GCC_INSTALL_PATH/gcc-$cross_gcc_version/$gcc_arch
	sudo mv $dir  $GCC_INSTALL_PATH/gcc-$cross_gcc_version/$gcc_arch
}

install_openrisc()
{
	local URL='https://github.com/openrisc/or1k-gcc/releases/download/or1k-5.4.0-20170218'
	local file='or1k-linux-5.4.0-20170218.tar.xz'

	download_extract "$URL/$file"

	local dir="$GCC_INSTALL_PATH/${gcc_arch}"
	local cross_gcc_version=(${dir}/bin/${gcc_arch}-gcc-*.*.*)
	local cross_gcc_version=${cross_gcc_version##*-}

	echo mkdir -p $GCC_INSTALL_PATH/gcc-$cross_gcc_version
	sudo mkdir -p $GCC_INSTALL_PATH/gcc-$cross_gcc_version
	echo mv $dir  $GCC_INSTALL_PATH/gcc-$cross_gcc_version/$gcc_arch
	sudo mv $dir  $GCC_INSTALL_PATH/gcc-$cross_gcc_version/$gcc_arch
}

install_cross_compiler()
{
	install_packages

	if [[ $gcc_arch =~ 'aarch64' ]]; then
		install_linaro
	elif [[ $gcc_arch =~ 'or1k' ]]; then
		install_openrisc
	else
		install_crosstool
	fi
}

setup_crosstool()
{
	local gcc_arch
	local gcc_exec

	case $ARCH in
		i386|x86_64)
			gcc_arch=
			;;
		um)
			gcc_arch=
			;;
		arm)
			gcc_arch=arm-unknown-linux-gnueabi
			;;
		arm64)
			gcc_arch=aarch64-linux-gnu
			;;
		powerpc)
			gcc_arch=powerpc64-linux
			;;
		blackfin)
			gcc_arch=bfin-uclinux
			;;
		sh)
			gcc_arch=sh4-linux
			;;
		parisc)
			if grep -s -q 'CONFIG_64BIT=y' $SRC_ROOT/arch/parisc/configs/$config; then
				gcc_arch=hppa64-linux
			else
				gcc_arch=hppa-linux
			fi
			;;
		openrisc)
			gcc_arch=or1k-linux
			;;
		s390)
			gcc_arch=s390x-linux
			;;
		tile|tilegx)
			gcc_arch=tilegx-linux
			;;
		mn10300)
			gcc_arch=am33_2.0-linux
			;;
		*)
			gcc_arch=$ARCH-linux
			;;
	esac

	if [[ $gcc_arch ]]; then
		gcc_exec=($GCC_INSTALL_PATH/gcc-*/${gcc_arch}/bin/${gcc_arch}-gcc)
		[[ -x $gcc_exec ]] || install_cross_compiler

		gcc_exec=($GCC_INSTALL_PATH/gcc-*/${gcc_arch}/bin/${gcc_arch}-gcc)
		[[ -x $gcc_exec ]] || {
			echo "No cross compiler for $ARCH"
			exit
		}

		# use highest available version
		gcc_exec=${gcc_exec[-1]}

		opt_cross="CROSS_COMPILE=${gcc_exec%gcc}"
	else
		opt_cross=
	fi
}

setup_crosstool

[[ "$*" =~ (-j|--jobs) ]] || {
	nr_cpu=$(getconf _NPROCESSORS_CONF)
	opt_jobs="--jobs=$((nr_cpu * 2))"
}

[[ "$*" =~ "ARCH=$ARCH" ]] || {
	opt_arch="ARCH=$ARCH"
}

if [ -d obj-$ARCH ]; then
	export KBUILD_OUTPUT=obj-$ARCH
	O=KBUILD_OUTPUT=obj-$ARCH
fi

[[ -f .make-env ]] && source ./.make-env

if [[ -d source && -L source ]]; then
	echo make -C source O=$PWD $opt_arch $opt_cross $subarch $opt_jobs "$@"
	exec make -C source O=$PWD $opt_arch $opt_cross $subarch $opt_jobs "$@"
else
	echo make $O $opt_arch $opt_cross $subarch $opt_jobs "$@"
	exec make $O $opt_arch $opt_cross $subarch $opt_jobs "$@"
fi
