#!/bin/sh

. $LKP_SRC/lib/detect-system.sh
. $LKP_SRC/lib/install.sh

set_ubuntu_debian()
{
	export DEBIAN_FRONTEND=noninteractive

	sed -e "s|http://ports.ubuntu.com|${mirror_addr}|g" \
		-e "s|http://ports.ubuntu.com|${mirror_addr}|g" \
		-e "s|http://deb.debian.org|${mirror_addr}|g" \
		-e "s|http://security.debian.org|${mirror_addr}|g" \
		-e "s|http://security.ubuntu.com|${mirror_addr}|g" \
		-e "s|http://archive.ubuntu.com|${mirror_addr}|g" \
		-i.bak \
		/etc/apt/sources.list
}

set_suse()
{
	sed -e "s|^baseurl=http://download.opensuse.org|baseurl=${mirror_addr}/opensuse|g" \
		-i.bak \
		/etc/zypp/repos.d/repo-*.repo
}

set_archlinux()
{
	if [ "$(uname -m)" = "aarch64" ]; then
		sed -i "1s;^;Server\\ =\\ ${mirror_addr}/archlinuxarm/\$arch/\$repo\\n;" /etc/pacman.d/mirrorlist
	else
		sed -i "1s;^;Server\\ =\\ ${mirror_addr}/archlinux/\$arch/\$repo\\n;" /etc/pacman.d/mirrorlist
	fi
}

set_fedora()
{
	sed -e 's|^metalink=|#metalink=|g' \
		-e "s|^#baseurl=http://download.example/pub/fedora/linux|baseurl=${mirror_addr}/fedora|g" \
		-i.bak \
		/etc/yum.repos.d/fedora*.repo
}

set_centos()
{
	. /etc/os-release

	case ${VERSION_ID} in
		7)
			sed -e 's|^mirrorlist=|#mirrorlist=|g' \
				-e "s|^#baseurl=http://mirror.centos.org/centos|baseurl=${mirror_addr}/centos|g" \
				-e "s|^#baseurl=http://mirror.centos.org/altarch|baseurl=${mirror_addr}/centos-altarch|g" \
				-e "s|^baseurl=http://mirror.centos.org/altarch|baseurl=${mirror_addr}/centos-altarch|g" \
				-i.bak \
				/etc/yum.repos.d/CentOS-*.repo
			;;
		8)
			sed -e 's|^mirrorlist=|#mirrorlist=|g' \
				-e "s|^#baseurl=http://mirror.centos.org/\$contentdir|baseurl=${mirror_addr}/centos|g" \
				-i.bak \
				/etc/yum.repos.d/CentOS-*.repo
			;;
		*)
			echo "local repo mirror not found for CentOS: ${VERSION_ID}"
			;;

	esac
}

adapt_lkp_depends()
{
	os=$(echo "${_system_name}" | tr '[:upper:]' '[:lower:]')
	lkp_depends=$(get_dependency_packages $os lkp | xargs)
}

get_package_manager()
{
        has_cmd "yum" && installer="yum"
        has_cmd "dnf" && installer="dnf" && return
        has_cmd "apt-get" && installer="apt-get" && return
        has_cmd "pacman" && installer="pacman" && return
        has_cmd "zypper" && installer="zypper" && return
}

install_depends()
{
	packages="$1"

	case "$installer" in
		apt-get)
			export DEBIAN_FRONTEND=noninteractive

			"${installer}" update >/dev/null
			"$installer" install -yqm ${packages}
			;;
		dnf|yum)
			"$installer" install -y -q --skip-broken ${packages}
			;;
		pacman)
			"$installer" -Sy --noconfirm --needed ${packages}
			;;
		zypper)
			"${installer}" -Sy --needed >/dev/null
			"$installer" -q install -y ${packages}
			;;
	esac
}

set_local_mirror()
{
	mirror_addr="http://${SRV_HTTP_OS_REPO_HOST}:${SRV_HTTP_OS_REPO_PORT}/os-repo"

	case "${_system_name}" in
		Ubuntu|Debian)
			set_ubuntu_debian
			;;
		SuSE|OpenSuSE)
			set_suse
			;;
		ArchLinux)
			set_archlinux
			;;
		Fedora)
			set_fedora
			;;
		CentOS)
			set_centos
			;;
		*)
			echo "local repo mirror not found for system: ${_system_name}, ${installer} use repos by default"
			;;
	esac
}