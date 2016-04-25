#!/bin/sh

## See 'tests/piglit'.

tset=${group%%-*}
groups_dir=$BENCHMARK_ROOT/piglit/groups
[ -d "$groups_dir" ] || groups_dir=$LKP_SRC/pack/piglit-addon/groups
[ -f "$groups_dir/$tset-all" ] || cat $groups_dir/$tset-[0-9][0-9][0-9] > $groups_dir/$tset-all

tmp_results="$TMP/piglit-results"
i=0

grep -F -x -f $groups_dir/$tset-all $groups_dir/$group |
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
echo all tests finished
