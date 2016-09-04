#!/bin/bash

## See 'tests/piglit'.

## Currently, just support the following two formats's test item,
## Using "igt" testcase as an example:
## - igt-$num (get test item from $LKP_SRC)
## - igt-all (get test item from $BENCHMARK_ROOT)

. $LKP_SRC/lib/upload.sh

tset=${group%%-*}

if [ "${group#*-}" = "all" ]; then
	config_file=$BENCHMARK_ROOT/piglit/groups/$group
else
	config_file=$LKP_SRC/pack/piglit-addon/groups/$group
fi

[ -f "$config_file" ] || {
	echo "config file not exist: $config_file" 1>&2
	exit 1
}

tmp_results="$TMP/piglit-results"

if [ -s "$LKP_SRC/pack/piglit-addon/groups/broken" ]; then
	testcases=$(grep -F -x -f $BENCHMARK_ROOT/piglit/groups/$tset-all $config_file | grep -F -x -v -f $LKP_SRC/pack/piglit-addon/groups/broken)
else
	testcases=$(grep -F -x -f $BENCHMARK_ROOT/piglit/groups/$tset-all $config_file)
fi

while read testcase
do
	start_time=$(date +%s.%N)
	log_cmd piglit run $tset -t "$testcase" "$tmp_results"
	end_time=$(date +%s.%N)
	id=$(echo "$testcase" | tr ' ' _).seconds
	elapsed=$(echo $end_time - $start_time | bc)
	echo "$id: $elapsed"
	log_cmd piglit summary console "$tmp_results/results.json.bz2"
	mv	"$tmp_results"/results.json.bz2 \
		"$tmp_results"/${testcase//[^A-Za-z0-9_-]/-}.json.bz2
done <<< "$testcases"

upload_files $tmp_results/*.json.bz2
echo "all tests finished"
