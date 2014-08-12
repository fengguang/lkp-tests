#!/bin/bash

[[ $1 ]] || exit

mv $1-quick .$1-quick
ls $1/??? | grep -v -f <(cat $1-*) | cut -f2 -d/ > $1-quick
