#!/bin/bash

for file
do
	script=${file%:*}
	script=${script##*/}
	echo \
	"$LKP_SRC/stats/$script < $file > ${file/:/.}"
	$LKP_SRC/stats/$script < $file > ${file/:/.}
done
