#!/bin/bash

for file in dmesg-*
do
	/lkp/lkp/src/stats/dmesg $file > ${file/-/.}
done
