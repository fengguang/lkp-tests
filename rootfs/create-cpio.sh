#!/bin/sh

distro=${1:-debian-x86_64}
arch=${distro#*-}

INITRD_ROOT=/osimage/debian

cd $distro || exit

[ -d "addon" ]		&& cp -a ../addon/* .
[ -d "addon-$arch" ]	&& cp -a ../addon-$arch/* .

cpio_file=$distro-$(date +%F).cgz

{ find . -xdev; find dev; } |
grep -v -f ../rootfs-strip-list |
cpio -o -H newc | gzip -n -9 > ../$cpio_file || exit

cd ..

echo
echo "To deploy the rootfs:"
echo "cp $cpio_file $INITRD_ROOT/$cpio_file"
echo "ln -fs $cpio_file $INITRD_ROOT/${distro}.cgz"
