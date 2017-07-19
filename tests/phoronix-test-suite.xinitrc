#!/bin/sh

. $LKP_SRC/lib/debug.sh

## See 'tests/phoronix-test-suite'.

start_time=$(date +%s.%N)

# ffmpeg only support max 64 threads
fixup_ffmpeg()
{
	local target=/var/lib/phoronix-test-suite/installed-tests/pts/ffmpeg-2.5.0/ffmpeg
	grep -q -w 'NUM_CPU_CORES=64' $target || sed "2a[ \$NUM_CPU_CORES -gt 64 ] && export NUM_CPU_CORES=64" -i "$target"
}

case $test in
	systester-[0-9]*)
		# Choose
		# 1: Gauss-Legendre algorithm [Recommended.]
		# 2: 16 Million Digits [This Test could take a while to finish.]
		# 3: 4 threads [2+ Cores Recommended]
		# todo: select different test according to testbox's hardware
		test_opt="\n1\n2\n3\nn"
		;;
	ffmpeg-2.5.0)
		fixup_ffmpeg
		;;
esac

export PTS_SILENT_MODE=1
echo PTS_SILENT_MODE=$PTS_SILENT_MODE

## this is to avoid to write the tmp "test-results" to disk
mount -t tmpfs tmpfs /var/lib/phoronix-test-suite/test-results || die "failed to mount tmpfs"

if [ "$test_opt" ]; then
	echo -e "$test_opt" | log_cmd phoronix-test-suite run $test
else
	echo n | log_cmd phoronix-test-suite default-run $test
fi

exit_value=$?

end_time=$(date +%s.%N)
elapsed=$(echo $end_time - $start_time | bc)
echo "${test}.seconds: $elapsed"

exit $exit_value
