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
		test_opt="1\n2\n3\nn"
		;;
esac

if [ "$test_opt" ]; then
	echo -e "$test_opt" | cmd phoronix-test-suite run $test
else
	echo n | cmd phoronix-test-suite default-run $test
fi

end_time=$(date +%s.%N)
elapsed=$(echo $end_time - $start_time | bc)
echo "${test}.seconds: $elapsed"
