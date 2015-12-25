#!/bin/sh

## See 'tests/phoronix-test-suite'.

start_time=$(date +%s.%N)

case $test in
	systester-[0-9]*)
		# Choose
		# 1: Gauss-Legendre algorithm [Recommended.]
		# 2: 16 Million Digits [This Test could take a while to finish.]
		# 3: 4 threads [2+ Cores Recommended]
		# todo: select different test according to testbox's hardware
		test_opt="\n1\n2\n3\nn"
		;;
esac

## We used the v5.6.0 version of "pts" before, but the enviroment variable "PTS_SILENT_MODE" only can work in more than v5.6.0 version.
## so we upgrade to v5.8.1 version, and it can work normally now.
export PTS_SILENT_MODE=1
echo PTS_SILENT_MODE=$PTS_SILENT_MODE

## Currently, we use the rootfs by NFS network, in order to avoid to write the "test-results" to NFSROOT, we mount the tmpfs on below directory.
mount -t tmpfs tmpfs /var/lib/phoronix-test-suite/test-results || exit

if [ "$test_opt" ]; then
	echo -e "$test_opt" | cmd phoronix-test-suite run $test
else
	echo n | cmd phoronix-test-suite default-run $test
fi

end_time=$(date +%s.%N)
elapsed=$(echo $end_time - $start_time | bc)
echo "${test}.seconds: $elapsed"
