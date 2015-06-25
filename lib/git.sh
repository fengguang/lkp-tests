#!/bin/sh

git_clone_update()
{
	local url=$1
	local dir=$2
	[ "$dir" ] || dir=$(basename $url .git)

	if [ -d $dir/.git ]; then
		(
			cd $dir
			for retry in 1 2
			do
				git remote update origin 2>&1 ||
				git remote update origin 2>&1
				git checkout -q origin/master 2>&1 && break
			done
		)
	else
		rm -fr "$dir" 2>/dev/null
		git clone -q $url $dir 2>&1 ||
		git clone -q $url $dir 2>&1 ||
		git clone -q $url $dir 2>&1
	fi
}

