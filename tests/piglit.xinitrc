#!/bin/sh

## See 'tests/piglit'.

## Currently, just support the following two formats's test item,
## Using "igt" testcase as an example:
## - igt-$num (get test item from $LKP_SRC)
## - igt-all (get test item from $BENCHMARK_ROOT)

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
i=0

grep -F -f $BENCHMARK_ROOT/piglit/groups/$tset-all $config_file |
while read testcase
do
	start_time=$(date +%s.%N)
	cmd piglit run $tset -t "$testcase" "$tmp_results"
	end_time=$(date +%s.%N)
	id=$(echo "$testcase" | tr ' ' _).seconds
	elapsed=$(echo $end_time - $start_time | bc)
	echo "$id: $elapsed"
	cmd piglit summary console "$tmp_results/results.json"
	mv		"$tmp_results"/results.json \
			"$tmp_results"/${i}.json
	i=$((i + 1))
done

copy-results	$tmp_results/*.json
echo "all tests finished"
