#!/bin/bash

[[ $(whoami) != 'root' ]] && {
	echo "run as root"
	exit
}

BASE_DIR=$(dirname $0)
cd $BASE_DIR

rm -fr rip
mkdir rip
cd rip
gzip -dc /tftpboot/rip/rootfs.cgz | cpio -imud
cd ..
cp -a addon/* rip/
cp -a etc rip/
cd rip
for i in ../packages/*.tgz
do
	tar zxf $i
done

# to find large files:
# less rootfs.cgz | sort -k5 -n

rm -fr lib/firmware
rm -fr opt
rm -fr usr/doc
rm -fr usr/man
rm -fr usr/info
rm -fr usr/lib/libclamav.so*

rm -fr usr/share/hwdata # pci.ids usb.ids
rm -f  usr/bin/truecrypt
rm -f  usr/bin/aria2c
rm -f  usr/bin/xorriso
rm -f  usr/bin/fsarchiver
rm -f  usr/sbin/tw_cli64
rm -f  usr/sbin/tw_cli32
rm -f  usr/sbin/partclone.*
rm -f  usr/bin/slrn
rm -f  usr/bin/zgv
rm -f  usr/sbin/zfs-fuse
rm -f  usr/bin/gpg
rm -f  usr/bin/mc
rm -f  usr/bin/omshell
rm -f  usr/bin/lynx
rm -f  usr/bin/mutt
rm -f  usr/bin/dig
rm -f  usr/bin/upx
rm -f  usr/bin/epic5
rm -f  sbin/tc
rm -f  sbin/lvm
rm -f  usr/bin/tin
rm -f  usr/bin/arj
rm -f  usr/sbin/tcpdump
rm -f  usr/bin/shunt
rm -f  sbin/xfs_db
rm -f  sbin/xfs_repair
rm -f  usr/bin/unrar
rm -f  lib/libdmraid.so.1.0.0.rc16
rm -f  lib/libmultipath.so.0
rm -f  usr/sbin/iscsid
rm -f  usr/bin/openssl
rm -f  usr/bin/mtpfs
rm -f  usr/lib/libnettle.so.4.0
rm -f  usr/lib/libpng14.so.14.5.0
rm -f  usr/lib/libfuse.so.2.8.5
rm -f  usr/sbin/wpa_supplicant
rm -f  usr/lib/libgpgme.so.11.7.0
rm -f  usr/lib/libtirpc.so.1.0.10

rm -fr etc/iscsi
rm -f  usr/bin/iscsi_discovery
rm -f  usr/sbin/iscsi-iname
rm -f  etc/iscsi/iscsid.conf
rm -f  usr/bin/iscsistart
rm -f  usr/bin/iscsiadm

rm -f  usr/sbin/partimaged-ssl
rm -f  usr/sbin/partimaged
rm -f  usr/sbin/partimage
rm -f  usr/sbin/partimage-ssl

rm -fr lib/modules
rm -fr usr/share/file
find usr/bin -size +1M -delete
rm -f  usr/lib/libmagic.so.1.0.0
rm -f  usr/lib/libsgutils2.so.2.0.0
rm -f  usr/lib/liblzo2.so.2.0.0
rm -f  usr/lib/libjpeg.so.8.0.1
rm -f  usr/lib/libreiser4-1.0.so.7.0.0
rm -f  usr/lib/libarchive.so.2.8.4
rm -f  usr/lib/libnl-route.so.3.0.0
rm -f  usr/lib/libnl.so.1.1
rm -f  usr/lib/libcurl.so.4.2.0
rm -f  usr/lib/libntfs-3g.so.813.0.0
rm -f  usr/lib/libafflib.so.0.0.0
rm -f  usr/lib/libtiff.so.3.9.4
rm -f  usr/lib/libgmp.so.10.0.1
rm -f  usr/lib/libparted.so.0.0.2
rm -f  usr/lib/libvga.so.1.9.25
rm -f  usr/lib/libewf.so.1.0.4
rm -f  usr/lib/librdd.so.1.2.0
rm -f  usr/lib/libgcrypt.so.11.5.3
rm -f  usr/lib/libsqlite3.so.0.8.6
rm -f  usr/lib/libgnutls.so.26.14.12
rm -f  usr/lib/libencfs.so.6.0.1
rm -f  usr/lib/libslang.so.2.2.3
rm -f  usr/lib/libstdc++.so.6.0.14
rm -f  usr/lib/libtsk3.so.3.3.2
rm -f  usr/lib/libglib-2.0.so.0.2800.5
rm -f  usr/lib/libxml2.so.2.7.8
rm -f  usr/lib/libdar.so.5.0.0

find . | bin/cpio -o -H newc | gzip -9 >../rootfs.cgz

cd ..
# rm -fr rip
