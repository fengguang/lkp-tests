#!/bin/sh

git_clone_update()
{
	local url=$1
	local dir
	shift

	if [ -n "$1" -a "$1" = "${1#-}" ]; then
		dir="$1"
		shift
	else
		dir=$(basename $url .git)
	fi

	source_dir=$PWD/$dir

	local git="timeout 60m git"

	if [ -d $dir/.git ]; then
		(
			cd $dir
			for retry in 1 2
			do
				echo \
				$git remote update origin
				$git remote update origin 2>&1 ||
				$git remote update origin 2>&1

				echo \
				$git checkout -q origin/master
				$git checkout -q origin/master 2>&1 && break
			done
		)
	else
		rm -fr "$dir" 2>/dev/null
		echo \
		$git clone -q "$@" $url $dir
		$git clone -q "$@" $url $dir 2>&1 ||
		$git clone -q "$@" $url $dir 2>&1 ||
		$git clone -q "$@" $url $dir
	fi
}

