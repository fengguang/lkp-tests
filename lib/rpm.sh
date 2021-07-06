#!/bin/bash

add_repo()
{
	[[ -n "$custom_repo_name" && -n "$custom_repo_addr" ]] || return 0

	custom_repo_name=($custom_repo_name)
	custom_repo_addr=($custom_repo_addr)

	for i in "${!custom_repo_name[@]}"
	do
		cat <<-EOF >> /etc/yum.repos.d/"${custom_repo_name[$i]}.repo"
		[${custom_repo_name[$i]}]
		name=${custom_repo_name[$i]}
		baseurl=${custom_repo_addr[$i]}
		enabled=1
		gpgcheck=0
		priority=100

		EOF
	done
}

fix_on_distro()
{
	source /etc/os-release
	case "${ID}-${VERSION_ID}" in
		centos-8|openEuler-20.03)
			# New version macro adapt
			sed -i '/%{?fedora} >\|%{?rhel} >/ s/$/ || %{?openEuler} == 2/' ${HOME}/rpmbuild/SPECS/*.spec
			;;
	esac
}
