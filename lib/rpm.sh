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
	case "${compat_os}" in
		compat-centos8)
			# New version macro adapt
			sed -i '/%{?fedora} >\|%{?rhel} >/ s/$/ || %{?openEuler} == 2/' ${spec_dir}/*.spec
			;;
		compat-fedora33)
			# Add fedora33 macro define
			if $(grep vimfiles_root ${spec_dir}/*.spec >/dev/null); then
				sed -i '1 i%global vimfiles_root %{_datadir}/vim/vimfiles' ${spec_dir}/*.spec
			fi
			# Fix fedora33 uniq macro: %cmake_build %cmake_install
			# ref: https://docs.fedoraproject.org/en-US/packaging-guidelines/CMake/
			sed -i '/^%cmake3/ s;$; ../;' ${spec_dir}/*.spec
			sed -i '/^%cmake3/i mkdir build && cd build/' ${spec_dir}/*.spec
			sed -i '/^%cmake_build/a %__cmake --build . %{?_smp_mflags} --verbose' ${spec_dir}/*.spec
			sed -i '/^%cmake_install/a DESTDIR="%{buildroot}" %__cmake --install ./build' ${spec_dir}/*.spec
			sed -i '/%cmake_install\|%cmake_build/ s/^/#/' ${spec_dir}/*.spec
			;;
	esac
}
