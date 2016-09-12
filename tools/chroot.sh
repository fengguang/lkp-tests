#!/bin/sh

mnt=$1

mountpoint -q $mnt/proc || {
	mount --rbind /dev	$mnt/dev
	mount --bind  /sys	$mnt/sys
	mount -t proc none	$mnt/proc
}

chroot $mnt
