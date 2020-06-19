#!/bin/bash -e

: ${LKP_SRC:=/c/lkp-tests}

job_yaml=$1
job_name=${job_yaml##*/}
job_dir=$(dirname $(realpath $job_yaml))
out_cgz=$job_dir/${job_name%.yaml}.cgz

tmp_dir=$job_dir/.tmp
lkp_dir=$tmp_dir/lkp/scheduled

mkdir -p $lkp_dir
cp -l $job_yaml $lkp_dir
$LKP_SRC/sbin/job2sh $job_yaml -o $lkp_dir/${job_name%.yaml}.sh

cd $tmp_dir
find lkp | cpio --quiet -o -H newc | gzip > $out_cgz

mv $lkp_dir/${job_name%.yaml}.sh $job_dir/
rm -fr $tmp_dir
