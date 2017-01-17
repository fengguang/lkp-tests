#!/bin/bash

for file in kmsg-*
do
	$LKP_SRC/stats/kmsg $file > ${file/-/.}
done
