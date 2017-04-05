#!/bin/sh

# usage: git_clone_update https://github.com/pmem/valgrind.git [dir] [--branch master]
git_clone_update()
{
	local url=$1
	local dir
	local branch=master
	shift

	if [ -n "$1" -a "$1" = "${1#-}" ]; then
		dir="$1"
		shift
	else
		dir=$(basename $url .git)
	fi

	if [ "$1" = "--branch" ] && [ -n "$2" ]; then
		branch=$2
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
				$git checkout -q origin/$branch
				$git checkout -q origin/$branch 2>&1 && break
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

# only can parse linux commit id
result_root_with_release_tag()
{
	local result_root=$1

	[[ $result_root =~ ^\/result/ ]] || {
		echo "invalid result_root: $result_root" >&2
		return 1
	}

	local commit=$(basename $(dirname $result_root))

	local author=$(git log -n1 --pretty=format:'%cn <%ce>' $commit 2> /dev/null)

	if [[ "$author" =~ "Linus Torvalds" ]]; then
		local commit_tag=$(git tag --points-at $commit | grep -m1 -E -e '^v[34]\.[0-9]+(|-rc[0-9]+)' -e '^v2\.[0-9]+\.[0-9]+(|-rc[0-9]+)')

		[[ $commit_tag ]] && {
			echo ${result_root/$commit/$commit_tag}
			return 0
		}
	fi

	echo $result_root
}
