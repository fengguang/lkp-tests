#!/bin/sh

distro=${1:-debian-x86_64}
arch=${distro#*-}

INITRD_ROOT=/osimage/debian

cd $distro || exit

cpio_file=$distro-$(date +%F).cgz

find . -xdev |
sed 's,^\./,,' |
grep -v -f ../rootfs-strip-list |
cpio -o -H newc | gzip -n -9 > ../$cpio_file || exit

cd ..

echo
echo "To deploy the rootfs:"
echo "cp $cpio_file $INITRD_ROOT/$cpio_file"
echo "ln -fs $cpio_file $INITRD_ROOT/${distro}.cgz"

# tuning tips:
# deborphan -sz
# deborphan -az
# apt-get purge $(deborphan) # check the list first
# dpkg-query -W -f='${Installed-Size} \t${Package} \t${Priority} \n'|sort -n
# less /osimage/debian/debian-x86_64.cgz|sort -k5 -n |less
