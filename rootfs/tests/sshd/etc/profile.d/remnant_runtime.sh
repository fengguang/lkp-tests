
displaysecs() {
	local T=$1
	local D=$((T/60/60/24))
	local H=$((T/60/60%24))
	local M=$((T/60%60))
	local S=$((T%60))
	printf "%d day %d:%d:%d" $D $H $M $S
}

calctime() {
	[ -n "$runtime" ] || return 0

	stime=$(awk -F. '{print $1}' /proc/uptime)
	ltime=$[runtime - $stime]

	[ "$ltime" -gt 0 ] || return
	time=$(displaysecs $ltime)

	echo -e "Remaining runtime \033[41m$time\033[0m"
	echo -e "\n"
}

calctime
