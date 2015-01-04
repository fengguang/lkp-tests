#!/bin/sh

setup_threads_to_iterate()
{
	threads_to_iterate=1
	nr_node=$(echo /sys/devices/system/node/node* | wc -w)

	local threads_per_core=$(lscpu | awk '/Thread\(s\) per core:/ { print $4 }')
	local cores_per_node=$((nr_cpu / nr_node / threads_per_core))

	# [    0.000000] Intel MultiProcessor Specification v1.4
	# [    0.000000]   mpc: 12-f012
	# [    0.000000] MPTABLE: bad signature [
	# [    0.000000] BIOS bug, MP table errors detected!...
	# [    0.000000] ... disabling SMP support. (tell your hw vendor)
	# [    0.000000] smpboot: Allowing 1 CPUs, 0 hotplug CPUs
	[ "$cores_per_node" = 0 ] && {
		echo "Invalid nr_cpu, nr_node or threads_per_core: $nr_cpu $nr_node $threads_per_core" >&2
		exit 1
	}

	local i
	for i in $(seq $nr_node)
	do
		threads_to_iterate="${threads_to_iterate} $((i * cores_per_node))"
	done

	[ "$nr_cpu" -ge 4 ] && {
		threads_to_iterate="${threads_to_iterate} $((nr_cpu * 3 / 4))"
		threads_to_iterate="${threads_to_iterate} $nr_cpu"
	}

	threads_to_iterate=$(echo $threads_to_iterate | tr ' ' '\n' | sort -un)
}
