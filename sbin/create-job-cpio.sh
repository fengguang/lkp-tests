#!/bin/bash -e

: ${LKP_SRC:=/c/lkp-tests}

job_yaml=$1
job_name=${job_yaml##*/}
out_cgz=$(dirname $(realpath $job_yaml))/${job_name%.yaml}.cgz

tmp_dir=/tmp/$$
lkp_dir=$tmp_dir/lkp/scheduled

mkdir -p $lkp_dir
cp $job_yaml $lkp_dir
$LKP_SRC/sbin/job2sh $job_yaml -o $lkp_dir/${job_name%.yaml}.sh

cd $tmp_dir
find lkp | cpio --quiet -o -H newc | gzip > $out_cgz

rm -fr $tmp_dir
