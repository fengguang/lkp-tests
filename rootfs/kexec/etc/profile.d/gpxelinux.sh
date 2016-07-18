#!/bin/bash

[[ $SSH_CLIENT ]] && return

if [ -f /tmp/gpxelinux-runonce ]; then
	return
else
	touch /tmp/gpxelinux-runonce
fi

for i in $(</proc/cmdline)
do
	[[ $i =~ [a-zA-Z_]+= ]] && eval $i
done

if [[ -z $path_prefix ]]; then
	path_prefix='http://bee.sh.intel.com/~lkp/'
fi
SERVER=${path_prefix##*://}
SERVER=${SERVER%%/*}

cat <<EOF
Welcome to KEXEC based gPXELINUX boot loader.

Copyright Intel OTC. 2010-2017 Fengguang Wu <fengguang.wu@intel.com>

EOF

has_ip()
{
	ifconfig | grep -A1 'HWaddr' | grep -q '\<inet\>'
}

for (( i = 0 ; i < 10 ; i++ ))
do
	[ -s /tmp/etc.tgz ] && break

	echo -n 'Waiting for IP '

	for (( j = 0 ; j < 10 ; j++ ))
	do
		if has_ip; then
			echo
			ifconfig | grep -A1 'HWaddr' | grep -B1 '\<inet\>'
			echo
			break
		else
			echo -n .
			sleep 1
		fi
	done

	lftp -c "set dns:fatal-timeout 10s; \
		set dns:max-retries 10; \
		set net:timeout 10s; \
		set net:max-retries 10; \
		set net:reconnect-interval-base 1; \
		set net:reconnect-interval-max  10; \
		open $path_prefix && \
		get -O /tmp usbkey/boot/kexec/etc.tgz" && break

	(( i > 2 )) && has_ip && break

	# In rare cases, the interfaces have not yet shown up when rc.inet1 was
	# initially called. Run it again to start DHCP on possible new interfaces.
	#
	# echo
	# ifconfig eth0 down
	# ifconfig eth0 up
	# mii-tool 2> /dev/null
	/etc/rc.d/rc.inet1 start
done

if [ -s /tmp/etc.tgz ]; then
	tar z -C /tmp -xf /tmp/etc.tgz
	cp -au /tmp/etc /
fi

for i in {1..9}
do
	/etc/rc.d/gpxelinux
	echo $0: sleeping for ${i}m ...
	sleep ${i}m || break
done
