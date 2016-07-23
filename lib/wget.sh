escape_cgi_param()
{
	local uri="$1"
	# uri=${uri//%/%25} # must be the first one
	# uri=${uri//+/%2B}
	# uri=${uri//&/%26}
	# uri=${uri//\?/%3F}
	# uri=${uri//@/%40}
	# uri=${uri//:/%3A}
	# uri=${uri//;/%3D}
	echo "$uri" |
	sed	-e 's/%/%25/g' \
		-e 's/+/%2B/g' \
		-e 's/&/%26/g' \
		-e 's/\?/%3F/g'
}

# usage: wget_resource <path> [wget options...]
wget_resource()
{
	local path="$1"
	shift

	# $ busybox wget http://XXX:/
	# wget: bad port spec 'XXX:'
	[ -n "$LKP_CGI_PORT" ] || echo "warning: LKP_CGI_PORT is empty"

	local http_prefix="http://$LKP_SERVER:${LKP_CGI_PORT:-80}/~$LKP_USER"
	local wget_encoding_option=

	# wget command may link to busybox which not support --local-encoding option
	[ -L '/usr/bin/wget' ] || wget_encoding_option="--local-encoding=UTF-8"

	local opt_retry=
	wget --help 2>&1 | grep -q '\--retry-connrefused' &&
	{
		opt_retry='--retry-connrefused --waitretry 1000 --tries 1000'
	}

	echo \
	wget -q $wget_encoding_option $opt_retry "$http_prefix/$path" "$@"
	wget -q $wget_encoding_option $opt_retry "$http_prefix/$path" "$@"
}

reset_broken_ipmi()
{
	[ -f "$RESULT_MNT/.IPMI-reset/$HOSTNAME" ] || return
	[ -x '/usr/sbin/bmc-device' ] || return

	bmc-device --cold-reset
	mv -f $RESULT_MNT/.IPMI-reset/$HOSTNAME $RESULT_MNT/.IPMI-reset/.$HOSTNAME
}

#
# job handling at client is finished, tell server to do some
# post handling, such as delete the job file, process all
# monitors data, and so on
#
trigger_post_process()
{
	wget_resource "cgi-bin/lkp-post-run?job_file="$(escape_cgi_param "$job") -O /dev/null

	reset_broken_ipmi
}

jobfile_append_var()
{
	[ -n "$job" ] || return

	# input example: "var1=value1" "var2=value2 value_with_space" ....
	[ -z "$*" ] && LOG_ERROR "no paramter specified at $FUNCTION" && return

	local query_str=job_file=$(escape_cgi_param "$job")
	for assignment in "$@"; do
		query_str="${query_str}&$(escape_cgi_param "$assignment")"
	done

	wget_resource "cgi-bin/lkp-jobfile-append-var?$query_str" -O /dev/null
}

set_job_state()
{
	jobfile_append_var "job_state=$1"
}
