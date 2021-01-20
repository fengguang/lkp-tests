#!/bin/bash

SCRIPT_DIR=$(dirname $(realpath $0))
PROJECT_DIR=$(dirname $SCRIPT_DIR)

. $PROJECT_DIR/lib/env.sh

# choose install function base on DISTRIBUTION
linux_dep()
{
	source /etc/os-release
	case $ID in
	ubuntu|debian)
		export DEBIAN_FRONTEND=noninteractive
		sudo apt-get install -yqm ruby-git ruby-activesupport ruby-rest-client ruby-dev libssl-dev gcc g++
		sudo gem install faye-websocket
		;;
	openEuler|fedora|rhel|centos)
		if type dnf > /dev/null 2>&1; then
			sudo dnf install -y --skip-broken ruby rubygems gcc gcc-c++ make ruby-devel git lftp
		else
			sudo yum install -y --skip-broken ruby rubygems gcc gcc-c++ make ruby-devel git lftp
		fi
		sudo gem install -f git activesupport rest-client faye-websocket
		;;
	*)
		echo "$ID not support! please install dependencies manually."
		;;
	esac
}


mac_dep()
{
	brew install ruby
	write_shell_profile "export PATH=/usr/local/opt/ruby/bin:$PATH"
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

set_env()
{
	write_host
	write_shell_profile "export LKP_SRC=$PWD"
	write_shell_profile "export PATH=\$PATH:\$LKP_SRC/sbin:\$LKP_SRC/bin"
	source $(shell_profile)
}

set_env
run
