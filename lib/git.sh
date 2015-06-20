#!/bin/sh

git_clone_update()
{
	local url=$1
	local dir=$2
	[ "$dir" ] || dir=$(basename $url .git)

	if [ -d $dir/.git ]; then
		(
			cd $dir
			git remote update origin
			git checkout origin/master
		)
	else
		rm -fr "$dir"
		git clone $url $dir
	fi
}

