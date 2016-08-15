#!/bin/bash

for file in dmesg-*
do
	$LKP_SRC/stats/dmesg $file > ${file/-/.}
done
