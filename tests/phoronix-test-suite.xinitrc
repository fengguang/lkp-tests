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
else
	cmd phoronix-test-suite run $test <<EOF
Test All Options
n
EOF
fi
end_time=$(date +%s.%N)
elapsed=$(echo $end_time - $start_time | bc)
echo "${test}.seconds: $elapsed"
