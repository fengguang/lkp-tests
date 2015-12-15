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
##
## "pts" just is a test framework, need to download a large amount of benchmarks to run.
## Unfortunately,the v5.6.0 and v5.8.0 use the different of directories to store the downloaded benchmark.
##
## For example:
## 1)the benchmarks are stored under directory /root/.phoronix-test-suite/installed-tests/ in 5.6.0 version.
## 2)the benchmarks are stored under directory /var/lib/phoronix-test-suite/installed-tests/ in 5.8.1 version.
##
## This will result in the newer version of "pts" will can't use the old benchmark which be located in /root.phoronix-test-suite/ directory.
## To avoid do too many modifies and download a large amount of benchmarks, we need to create the below softlink:
##
## ln -sf /var/lib/phoronix-test-suite  /root/.phoronix-test-suite
##
## Thus the new version of "pts" could continue to use the old benchmarks, and it can work normally. 

export PTS_SILENT_MODE=1
echo PTS_SILENT_MODE=$PTS_SILENT_MODE

if [ "$test_opt" ]; then
	echo -e "$test_opt" | cmd phoronix-test-suite run $test
else
	echo n | cmd phoronix-test-suite default-run $test
fi

end_time=$(date +%s.%N)
elapsed=$(echo $end_time - $start_time | bc)
echo "${test}.seconds: $elapsed"
