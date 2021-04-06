#!/bin/bash

handle_FROM()
{
        sed -i "s/^FROM .*/FROM openeuler-20.03-lts:v1/g" "$dockerfile_name"
}

handle_epel()
{
	sed -i "s/epel-release/bash/g" "$dockerfile_name"
}

handle_epelrpm()
{
	sed -i "s|https://.*epel-release.*rpm|bash|g" "$dockerfile_name"
}

handle_rpm_gpg()
{
	sed -i "s|RPM-GPG-KEY-CentOS-7|RPM-GPG-KEY-openEuler|g" "$dockerfile_name"
	sed -i "s|RPM-GPG-KEY-centosofficial|RPM-GPG-KEY-openEuler|g" "$dockerfile_name"
}

add_base_commands()
{
        # grep -qw "groupadd*" "$file" && {
        # fix missing useradd, groupadd, chpasswd, etc. commands
        sed -i '/FROM /a\RUN yum -y install shadow tar' "$dockerfile_name"
}

handle_epel_repo()
{
        sed -i '/.* wget .*(epel|CentOS-Base)\.repo/ s|^|#|g' "$dockerfile_name"
}

handle_error_exit()
{
	sed '/^RUN/RUN set -e;/g' "$dockerfile_name"
}

handle_dockerfile()
{
	dockerfile_name=$1
	handle_FROM
	handle_epel
	handle_epelrpm
	handle_rpm_gpg
	add_base_commands
	handle_epel_repo
	handle_error_exit
}
