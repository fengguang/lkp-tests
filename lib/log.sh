#!/bin/bash

log_debug()
{
	echo "$(date +'%F %T') DEBUG -- $*"
}

log_warn()
{
	echo "$(date +'%F %T') WARN -- $*" >&2
}

log_error()
{
	echo "$(date +'%F %T') ERROR -- $*" >&2
}
