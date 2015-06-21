#!/bin/bash

make()
{
	echo "$(date +'%F %T') make -j $nr_cpu $*"

	/usr/bin/make -j $nr_cpu "$@"
}

build_complete()
{
	echo "$(date +'%F %T') make finished"
}
