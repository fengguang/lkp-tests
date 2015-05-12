#!/bin/bash

export RESULT_MNT='/result'
export RESULT_PATHS='/lkp/paths'

set_tbox_group()
{
	local tbox=$1

	if [[ $tbox =~ ^(.*)-[0-9]+$ ]]; then
		tbox_group=${BASH_REMATCH[1]}
	else
		tbox_group=$tbox
	fi
}

