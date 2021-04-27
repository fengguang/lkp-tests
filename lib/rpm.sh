#!/bin/bash

add_repo()
{
	custom_repo_name=($custom_repo_name)
	custom_repo_addr=($custom_repo_addr)

	for i in ${!custom_repo_name[@]}
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
