#!/bin/bash

all_lines=
:> all-stats
:> keep-unique
:> remove-no-stat

for file in dmesg-*
do
	stat=${file/-/.}
	[[ -s $stat ]] || /lkp/lkp/src/stats/dmesg $file > $stat
	[[ -s $stat ]] || {
		echo $file >> remove-no-stat
		continue
	}

	grep '^[a-zA-Z].*: 1' $stat |
	grep -v -e '^boot_failures:' -e '^timestamp:' -e '^calltrace:' -e '^RIP' -e 'EIP' |
	while read line
	do
		grep -qxF "$line" all-stats && continue
		echo "$line" >> all-stats
		echo $file >> keep-unique
	done
done
