#!/bin/bash

. lib/env.sh

# choose install function base on 
# DISTRIBUTION
linux_dep()
{
source /etc/os-release
case $ID in
ubuntu|debian)
	export DEBIAN_FRONTEND=noninteractive
	apt-get install -yqm ruby-git ruby-activesupport ruby-rest-client
	;;
openEuler|fedora|rhel|centos)
	if type dnf > /dev/null 2>&1; then
		dnf install -y --skip-broken ruby rubygems gcc gcc-c++ make ruby-devel git
	else
		yum install -y --skip-broken ruby rubygems gcc gcc-c++ make ruby-devel git
	fi
	gem install -f git activesupport rest-client
	;;
*)
	echo "$ID not support! please install dependencies manually."
	;;
esac
}


mac_dep()
{
	brew install ruby
	echo "export PATH=/usr/local/opt/ruby/bin:$PATH" >> $(shell_profile)
	source $(shell_profile)
	gem install git activesupport rest-client
}

run()
{
	if is_system "Linux"; then
		linux_dep
	elif is_system "Darwin"; then
		mac_dep
	else
		echo "$DISTRO not supported!"
	fi
}

run
