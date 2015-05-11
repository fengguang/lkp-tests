#!/bin/sh

start_time=$(date +%s.%N)

if [ $(echo $test | grep tiobench) ]; then
	cmd phoronix-test-suite run $test <<EOF
Test All Options
Test All Options
Test All Options
Test All Options
n
EOF
elif [ $(echo $test | grep systester) ]; then
	# Choose  
	# 1: Gauss-Legendre algorithm [Recommended.]
	# 2: 16 Million Digits [This Test could take a while to finish.]
	# 3: 4 threads [2+ Cores Recommended]
	# todo: select different test according to testbox's hardware
	cmd phoronix-test-suite run $test <<EOF
1
2
3
n
EOF
elif [ $(echo $test | grep interbench) ]; then
	cmd phoronix-test-suite run $test <<EOF
Test All Options
Test All Options
n
EOF
elif [ $(echo $test | grep iozone) ]; then
	cmd phoronix-test-suite run $test <<EOF
Test All Options
Test All Options
Test All Options
n
EOF
else
	cmd phoronix-test-suite run $test <<EOF
Test All Options
n
EOF
fi
end_time=$(date +%s.%N)
elapsed=$(echo $end_time - $start_time | bc)
echo "${test}.seconds: $elapsed"
