#!/bin/bash

## See 'tests/piglit'.

## Currently, just support the following two formats's test item,
## Using "igt" testcase as an example:
## - igt-$num (get test item from $LKP_SRC)
## - igt-all (get test item from $BENCHMARK_ROOT)

. $LKP_SRC/lib/debug.sh
. $LKP_SRC/lib/upload.sh

test=${group%%-*}

config_file=$BENCHMARK_ROOT/piglit/groups/$group

[ -f "$config_file" ] || die "can not find config file: $config_file"

tmp_results="$TMP/piglit-results"

while read errorcase
do
  echo "The wrong test $errorcase will cause the piglit to crash and will not be run" >&2
done < <(grep -F -x -v -f $BENCHMARK_ROOT/piglit/groups/$test-all $config_file)

if [ -s "$LKP_SRC/pack/piglit-addon/groups/ignored_by_lkp" ]; then
	testcases=$(grep -F -x -f $BENCHMARK_ROOT/piglit/groups/$test-all $config_file | grep -F -x -v -f $LKP_SRC/pack/piglit-addon/groups/ignored_by_lkp)

	ignored_cases=$(grep -F -x -f $BENCHMARK_ROOT/piglit/groups/$test-all $config_file | grep -F -x -f $LKP_SRC/pack/piglit-addon/groups/ignored_by_lkp)
	for ignored_case in $ignored_cases
	do
		echo "$ignored_case: ignored_by_lkp"
	done
else
	testcases=$(grep -F -x -f $BENCHMARK_ROOT/piglit/groups/$test-all $config_file)
fi
[ -n "$testcases" ] || die "can not get piglit test cases"

while read testcase
do
	start_time=$(date +%s.%N)
	# in order for piglit to correctly identify testcase, change the special characters('/', '[', ']') in testcase to '.'
	# change spec/ext_transform_feedback/output-type.mat3[2]-no-subscript to spec.ext_transform_feedback.output-type.mat3.2.-no-subscript
	testcase=$(echo $testcase | tr "/[]" .)
	# using excluding(-x) to avoid running all matching case
	log_cmd piglit run $test -t "$testcase" "$tmp_results" -x "${testcase}."
	end_time=$(date +%s.%N)
	id=$(echo "$testcase" | tr ' ' _).seconds
	elapsed=$(echo $end_time - $start_time | bc)
	echo "$id: $elapsed"
	log_cmd piglit summary console "$tmp_results/results.json.bz2"
	mv	"$tmp_results"/results.json.bz2 \
		"$tmp_results"/${testcase//[^A-Za-z0-9_-]/-}.json.bz2
done <<< "$testcases"

upload_files -t results $tmp_results/*.json.bz2
echo "all tests finished"
