#!/bin/bash

add_repo()
{
	[[ -n "$mount_repo_name" && -n "$mount_repo_addr" ]] || return 0

	mount_repo_name=($mount_repo_name)
	mount_repo_addr=($mount_repo_addr)

	for i in "${!mount_repo_name[@]}"
	do
		repo_file_name=($(echo "$i" | tr '/' '-'))
		cat <<-EOF >> /etc/yum.repos.d/"${repo_file_name}.repo"
		[${repo_file_name}]
		name=${repo_file_name}
		baseurl=${mount_repo_addr[$i]}
		enabled=1
		gpgcheck=0
		priority=100

		[${repo_file_name}-source]
		name=${repo_file_name}-source
		baseurl=${mount_repo_addr[$i]%/*}/source
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

yum_repo_retry()
{
        for i in {1..3}
        do
                yum makecache > /dev/null && return
                [[ "${i}" < 3 ]] && sleep 10
        done
        exit 1
}

export_compat_os_base_version()
{
        source /etc/os-release

        case ${ID} in
                centos)
                        case ${VERSION_ID} in
                                6)
                                        export compat_os=compat-centos6
                                        ;;
                                7)
                                        export compat_os=compat-centos7
                                        ;;
                                8)
                                        export compat_os=compat-centos8
                                        ;;
                        esac
			;;
                fedora)
                        case ${VERSION_ID} in
                                33)
                                        export compat_os=compat-fedora33
                                        ;;
                                34)
                                        export compat_os=compat-fedora34
                                        ;;
                        esac
			;;
	esac
}
