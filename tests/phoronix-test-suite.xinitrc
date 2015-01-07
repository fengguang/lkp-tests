#!/bin/sh

start_time=$(date +%s.%N)
cmd phoronix-test-suite run $test <<EOF
Test All Options
n
EOF
end_time=$(date +%s.%N)
elapsed=$(echo $end_time - $start_time | bc)
echo "${test}.seconds: $elapsed"
