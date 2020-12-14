#!/bin/sh

. lib/env.sh

write_shell_profile()
{
	shell_profile_file=$(shell_profile)
	if [ $# -gt 0 ]; then
		echo $@ >> $shell_profile_file
	else
		echo "export LKP_SRC=$PWD" >> $shell_profile_file
		echo "export PATH=\$PATH:\$LKP_SRC/sbin:\$LKP_SRC/bin" >> $shell_profile_file
	fi

	source $shell_profile_file
}

write_host()
{
	if is_system "Linux"; then
		nr_cpu=$(nproc)
		memory_total=$(cat /proc/meminfo |grep MemTotal | awk '{print $2}')
        else
		nr_cpu=$(sysctl -n hw.logicalcpu)
		memory_total=$(top -l 1 | grep MemRegions | awk '{print $2}')
        fi
        memory_new=$(awk 'BEGIN{printf "%0.2f", '$memory_total'/1024/1024}')
        memory=$(echo $memory_new | awk '{print int($0)+1}')G

	cat > hosts/$(hostname) <<-EOF
	nr_cpu: $nr_cpu
	memory: $memory
	hdd_partitions:
	ssd_partitions:
	EOF
}

write_shell_profile
write_host
