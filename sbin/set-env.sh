#!/bin/sh

write_shellrc()
{
	echo "export LKP_SRC=$PWD" >> $HOME/.${SHELL##*/}rc
	echo "PATH=\$PATH:$PWD/sbin:$PWD/bin" >> $HOME/.${SHELL##*}rc
}

write_host()
{
	cat > hosts/$(hostname) <<-EOF
nr_cpu: $(nproc)
memory: $(ruby -e 'puts gets.split[1].to_i >> 20' < /proc/meminfo)G
hdd_partitions:
ssd_partitions:
EOF
}

write_shellrc
write_host
