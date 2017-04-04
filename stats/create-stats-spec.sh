#!/bin/bash

for file
do
	script=${file%.[0-9]*}
	script=${script##*/}
	echo \
	"$LKP_SRC/stats/$script < $file > ${file}.yaml"
	$LKP_SRC/stats/$script < $file > ${file}.yaml
done
