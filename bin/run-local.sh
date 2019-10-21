#!/bin/bash

[ -n "$LKP_SRC" ] || export LKP_SRC=$(dirname $(dirname $(readlink -e -v $0)))
export TMP=/tmp/lkp
export PATH=$PATH:$LKP_SRC/bin
export BENCHMARK_ROOT=/lkp/benchmarks

usage()
{
	cat <<EOF
Usage: run-local [-o RESULT_ROOT] JOB_SCRIPT

options:
    -o  RESULT_ROOT         dir for storing all results
EOF
	exit 1
}

update_export_variables()
{
	local cur_variables=$(export -p | sed -E 's/(export |declare -x )//g')
	local new_variables=$(bash -c "
	. $job_script
	export_top_env
	export -p | sed -E 's/(export |declare -x )//g'
	")

	local tmp_job_script=$(mktemp -u /tmp/job-script.XXXXXXXXX)
	cp $job_script $tmp_job_script

	for var in $(echo "$cur_variables" | grep -v -f <(echo "$new_variables"))
	do
		local var_name=${var%%=*}
		grep -q "export $var_name=" $tmp_job_script &&\
		sed -i "s/export $var_name=.*$/export $var/g" $tmp_job_script
	done

	mv $tmp_job_script "$opt_result_root/job.sh" &&
	job_script="$opt_result_root/job.sh"
}

while getopts "o:" opt
do
	case $opt in
	o ) opt_result_root="$OPTARG" ;;
	? ) usage ;;
	esac
done

shift $(($OPTIND-1))
job_script=$1
[ -n "$job_script" ] || usage
job_script=$(readlink -e -v $job_script)

if [ -z $opt_result_root ]; then
	[ -n "$RESULT_ROOT" ] || {
		echo "$0 exit due to RESULT_ROOT is not specified, you can use either"
		echo "\"-o RESULT_ROOT\" or \"export RESULT_ROOT=<result_root>\" to specify it.\n"
		usage
	}

	mkdir -p -m 02775 $RESULT_ROOT
else
	mkdir -p -m 02775 $opt_result_root
	export RESULT_ROOT=$(readlink -e -v $opt_result_root)
fi

export TMP_RESULT_ROOT=$RESULT_ROOT
export LKP_LOCAL_RUN=1
rm -rf $TMP
mkdir $TMP

update_export_variables

$job_script run_job

$LKP_SRC/bin/post-run
$LKP_SRC/bin/event/wakeup job-finished
