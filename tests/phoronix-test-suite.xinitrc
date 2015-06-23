#!/bin/sh

## See 'tests/phoronix-test-suite'.

start_time=$(date +%s.%N)

case $test in
	tiobench-[0-9]*)
		test_opt="Test All Options\nTest All Options\nTest All Options\nTest All Options\nn"
		;;
	systester-[0-9]*)
		# Choose
		# 1: Gauss-Legendre algorithm [Recommended.]
		# 2: 16 Million Digits [This Test could take a while to finish.]
		# 3: 4 threads [2+ Cores Recommended]
		# todo: select different test according to testbox's hardware
		test_opt="1\n2\n3\nn"
		;;
	interbench-[0-9]*)
		test_opt="Test All Options\nTest All Options\nn"
		;;
	iozone-[0-9]*)
		test_opt="Test All Options\nTest All Options\nTest All Options\nn"
		;;
	ramspeed-[0-9]*)
		test_opt="Test All Options\nTest All Options\nn"
		;;
	*)
		test_opt="Test All Options\nn"
		;;
esac

cmd phoronix-test-suite run $test <<EOF
$(echo -e $test_opt)
EOF

end_time=$(date +%s.%N)
elapsed=$(echo $end_time - $start_time | bc)
echo "${test}.seconds: $elapsed"
