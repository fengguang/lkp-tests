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

is_mrt()
{
	local dir=$1
	local -a jobs
	local -a matrix
	matrix=( $dir/matrix.json* )
	[ ${#matrix} -eq 0 ] && return 1
	jobs=( $dir/[0-9]*/job.yaml )
	[ ${#jobs} -ge 1 ]
}

# expand v4.1 etc. to commit SHA1
# eg: /gcc-4.9/v4.1/ => /gcc-4.9/b953c0d234bc72e8489d3bf51a276c5c4ec85345/
expand_tag_to_commit()
{
	local param=$1
	local git_tag
	local commit

	[[ "$param" =~ (v[0-9].[0-9]+[_-rc0-9]*) ]] &&
	{
		git_tag=$BASH_REMATCH
		git_tag="${git_tag%/*}"

		commit=$(git rev-list -n1 "$git_tag" 2>/dev/null) &&
		[[ $commit ]] && param="${param/$git_tag/$commit}"
	}

	echo "$param"
}

cleanup_path_record_from_patterns()
{

	local pattern
	local flag_pattern=0
	local cmd
	local path_file
	local dot_temp_file

	for pattern
	do
		pattern=$(expand_tag_to_commit $pattern)

		if [[ "$flag_pattern" = "0" ]]; then
			cmd="/${pattern//\//\\/}/"
			flag_pattern=1
		else
			cmd="$cmd && /${pattern//\//\\/}/"
		fi
	done

	[[ -d "/lkp/.paths/" ]] || mkdir "/lkp/.paths/" || return
	dot_temp_file=$(mktemp -p /lkp/.paths/ .tmpXXXXXX)

	for path_file in $(grep -l "$pattern" /lkp/paths/????-??-??-* /lkp/paths/.????-??-??-*)
	do
		awk "BEGIN {modified=0} $cmd {modified=1;next}; {print} END {exit 1-modified}" $path_file > $dot_temp_file &&
		mv -f $dot_temp_file $path_file
	done

	rm -f $dot_temp_file
}
