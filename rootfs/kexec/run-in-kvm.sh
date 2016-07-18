#!/bin/bash

kvm_params=(
-m 2G
-kernel vmlinuz
-initrd rootfs.cgz
-append hostname=vm-kexec
-net nic,vlan=0,macaddr=00:00:00:00:00:ff,model=e1000
-net user,vlan=0,hostfwd=tcp::2222-:22
)

qemu-system-x86_64 --enable-kvm "${kvm_params[@]}"

