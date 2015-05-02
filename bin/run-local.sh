#!/bin/sh

[ -n "$LKP_SRC" ] || export LKP_SRC=$(dirname $(dirname $(readlink -e -v $0)))
export TMP=/tmp/lkp
export PATH=$PATH:$LKP_SRC/bin
export BENCHMARK_ROOT=/lkp/benchmarks

usage()
{
	cat <<EOF
Usage: run-local [--dry-run] [-o RESULT_ROOT] JOB_SCRIPT

options:
    -o  RESULT_ROOT         dir for storing all results
EOF
	exit 1
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
	[ -n "$RESULT_ROOT" ] || usage
	mkdir -p -m 02775 $RESULT_ROOT
else
	mkdir -p -m 02775 $opt_result_root
	export RESULT_ROOT=$(readlink -e -v $opt_result_root)
fi

export TMP_RESULT_ROOT=$RESULT_ROOT
rm -rf $TMP
mkdir $TMP

$job_script run_job

$LKP_SRC/bin/post-run
