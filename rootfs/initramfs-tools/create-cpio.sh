#!/bin/sh

dir=$1

cd "$dir" || exit

echo "\
find * | cpio -o -H newc | gzip -n -9 > ../$dir.cgz"
find * | cpio -o -H newc | gzip -n -9 > ../$dir.cgz

cd ..

ln -fs $dir.cgz initramfs.cgz
