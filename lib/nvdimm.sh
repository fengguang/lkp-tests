# nvdimm functions

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lkp/benchmarks/ndctl/lib/
configure_nvdimm()
{
	for ns in $(ls -d /sys/bus/nd/devices/namespace*); do
		bns=$(basename $ns)
		rmode=$(cat "$ns/mode")
		rsize=$(cat "$ns/size")
		[ "$rsize" -eq 0 ] && continue
		rmode=$(echo -n $rmode)
		mode=$(echo -n $mode)
		[ "$rmode" = "$mode" ] && continue
		/lkp/benchmarks/ndctl/bin/ndctl create-namespace --reconfig=$bns \
						--force --mode="$mode" || exit 1
	done
}
