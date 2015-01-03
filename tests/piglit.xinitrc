#!/bin/bash

tset=${group%%-*}
groups_dir=$BENCHMARK_ROOT/piglit/groups
[ -d "$groups_dir" ] || groups_dir=$LKP_SRC/pack/piglit-addon/groups
[ -f "$groups_dir/$tset-all" ] || cat $groups_dir/$tset-[0-9][0-9][0-9] > $groups_dir/$tset-all

testcases=()
while read testcase
do
	testcases+=( "$testcase" )
done <<< "$(grep -F -x -f $groups_dir/$tset-all $groups_dir/$group)"

mkdir $RESULT_ROOT/results
i=0
for testcase in "${testcases[@]}"
do
	start_time=$(date +%s.%N)
	cmd piglit run $tset -t "$testcase" $TMP/piglit-results-$i
	end_time=$(date +%s.%N)
	echo "${testcase// /_}".seconds: $(echo $end_time - $start_time | bc)
	cmd piglit summary console $TMP/piglit-results-$i
	cp $TMP/piglit-results-$i/results.json $RESULT_ROOT/results/${i}.json
	(( i++ ))
done

echo all tests finished
