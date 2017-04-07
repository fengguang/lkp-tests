#!/bin/bash

for i in /pkg/linux/*/gcc-*/v4.8-rc1
do
	cd $i &&
	/c/kernel-tests/top-crash-heads
done

cd /pkg/linux/x86_64-rhel/gcc-6 || exit

for i in v4.*
do
	cd /pkg/linux/x86_64-rhel/gcc-6/$i &&
	/c/kernel-tests/top-crash-heads
done

cat /pkg/linux/*/gcc-*/v4.8-rc1/first-oops > /tmp/first-oops
cat /pkg/linux/x86_64-rhel/gcc-6/v4.*     >> /tmp/first-oops

mkdir -p /tmp/oops || exit
cd       /tmp/oops || exit
awk -v RS= '{print > ("dmesg-" NR )}' /tmp/first-oops

find -size -500c -name 'dmesg-*' -delete
find -size +5k -name 'dmesg-*' -delete
