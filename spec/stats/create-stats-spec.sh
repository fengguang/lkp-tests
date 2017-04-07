#!/bin/bash

for file
do
	script=${file%.[0-9]*}
	script=${script##*/}
	echo \
	"$LKP_SRC/stats/$script < $file > ${file}.yaml"
	if [[ $script =~ ^(dmesg|kmsg)$ ]]; then
		$LKP_SRC/stats/$script < $file > ${file}.yaml
	else
		$LKP_SRC/stats/$script   $file > ${file}.yaml
	fi
done
