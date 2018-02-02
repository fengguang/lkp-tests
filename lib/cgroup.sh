#!/bin/sh

. $LKP_SRC/lib/reproduce-log.sh

#Clear cgroups and subsystem controllers mount point for v1 version
clear_cgroup() 
{
	cgmounts=$(grep ' cgroup ' /proc/mounts)

	if [ -n "$cgmounts" ]; then
		echo "$cgmounts" |
		while read line
		do
			subsys=$(echo $line | awk '{ print $1 }')
			subsys_mount=$(echo $line | awk '{ print $2 }')
			if [ $(basename $subsys_mount) = "systemd" ]; then
				continue
			fi
			cgroups=$(find $subsys_mount -type d | tail -n +2 | tac)
			for cgroup in $cgroups
			do
				rmdir $cgroup 2>/dev/null
			done
			umount $subsys_mount
		done
	fi
}

#clear cgroups and subsystem controllers mount point for v2 version
clear_cgroup2()
{
	cgroup2_mount=$(grep ' cgroup2 ' /proc/mounts | awk '{ print $2 }')

	if [ -n "$cgroup2_mount" ]; then
		cgroups2=$(find $cgroup2_mount -type d | tail -n +2 | tac)
		for cgroup2 in $cgroups2
		do
			rmdir $cgroup2
		done
		umount $cgroup2_mount
	fi
}

#Bind each subsystem to an individual hierachy and create an individual control group
create_cgroup()
{
	local CGROUP_MNT=$1
	local testcase=$2

	subsys=$(awk 'NR > 1 {printf $1 " "}' /proc/cgroups)

	for item in $subsys
	do
		[ "$item" = "cpu" -o "$item" = "cpuacct" ] && {
			log_cmd mkdir -p $CGROUP_MNT/cpu,cpuacct 2>/dev/null
			log_cmd mount -t cgroup -o cpu,cpuacct cpu,cpuacct $CGROUP_MNT/cpu,cpuacct 2>/dev/null
			log_cmd mkdir -p $CGROUP_MNT/cpu,cpuacct/$testcase
			continue
		}
		log_cmd mkdir -p $CGROUP_MNT/$item
		log_cmd mount -t cgroup -o $item $item $CGROUP_MNT/$item
		log_cmd mkdir -p $CGROUP_MNT/$item/$testcase
	done
}

#Bind all the subsystem controllrs to an unified hierachy and create a control group
create_cgroup2()
{
	local CGROUP2_MNT=$1
	local testcase=$2

	log_cmd mkdir -p $CGROUP2_MNT
	log_cmd mount -t cgroup2 none $CGROUP2_MNT
	sub_controllers=$(cat $CGROUP2_MNT/cgroup.controllers)

	for controller in $sub_controllers
	do
		log_eval "echo '+$controller' > '$CGROUP2_MNT/cgroup.subtree_control'"
	done

	log_cmd mkdir -p $CGROUP2_MNT/$testcase
}
