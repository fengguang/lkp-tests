#!/bin/sh

. $LKP_SRC/lib/upload.sh
. $LKP_SRC/lib/wait.sh

TRACING=/sys/kernel/debug/tracing
FTRACE_EVENTS_DIR=$TMP/ftrace_events

ftrace_get()
{
	local target=$1
	cat $TRACING/$target
}

ftrace_set()
{
	local target=$1
	shift
	stdbuf -oL echo "$@" > $TRACING/$target
}

ftrace_append()
{
	local target=$1
	shift
	stdbuf -oL echo "$@" >> $TRACING/$target
}

echo_time()
{
	date +"%F %T $(printf "%s " "$@" | sed 's/%/%%/g')"
}

ftrace_reset()
{
	ftrace_set tracing_on 0
	ftrace_set current_tracer nop
	for knob in set_event set_ftrace_filter set_graph_function trace
	do
		ftrace_set $knob
	done
}

ftrace_test_save_time_delta()
{
	local time_delta_file=$TMP_RESULT_ROOT/ftrace_time_delta

	[ "$HOSTNAME" = avoton2 ] &&
		grep -q -F uptime $TRACING/trace_clock && {
			ftrace_set trace_clock uptime
			echo 0 > $time_delta_file
			return
		}

	ftrace_reset
	ftrace_set tracing_on 1
	local date_ts="$(date '+%s.%N')"
	ftrace_set trace_marker a long long timestamp detect string
	local trace_ts="$(grep -m1 -o '[0-9.]\+: tracing_mark_write: a long long timestamp detect string' $TRACING/trace)" || {
		echo "Failed to detect ftrace time delta."
		exit 0
	}
	ftrace_set tracing_on 0
	echo "$date_ts - ${trace_ts%%:*}" | bc > $time_delta_file
	ftrace_set trace
}

ftrace_set_params()
{
	if [ -z "$delay" ]; then
		if [ -n "$runtime" ]; then
			delay=$((runtime / 2))
		else
			delay=100
		fi
	fi

	: ${duration:=10}
	: ${current_tracer:=nop}

	# ftrace_test_save_time_delta
	ftrace_reset

	[ -n "$buffer_size_kb" ] && ftrace_set buffer_size_kb $buffer_size_kb

	if [ -n "$events" ]; then
		mkdir -p $FTRACE_EVENTS_DIR
		for evt in $events; do
			ftrace_append set_event $evt
			fmt=$(echo $TRACING/events/*/$evt/format)
			if [ -f $fmt ]; then
				cp $fmt $FTRACE_EVENTS_DIR/$evt.fmt
			fi
		done
	fi

	ftrace_set current_tracer $current_tracer

	if [ -n "$ftrace_filters" ]; then
		for f in $ftrace_filters; do
			ftrace_append set_ftrace_filter $f
		done
	fi

	if [ -n "$graph_functions" ]; then
		for f in $graph_functions; do
			ftrace_append set_graph_function $f
		done
	fi

	if [ -n "$ftrace_options" ]; then
		for opt in $ftrace_options; do
			ftrace_set trace_options $opt
		done
	fi

	[ -n "$trace_clock" ] && ftrace_set trace_clock $trace_clock
}

ftrace_show_params()
{
	for param in buffer_size_kb set_event current_tracer set_ftrace_filter \
				    set_graph_function tracing_on trace_options
	do
		echo $param: $(ftrace_get $param)
	done
}

ftrace_start()
{
	echo_time start tracing
	ftrace_set tracing_on 1
}

ftrace_stop()
{
	ftrace_set tracing_on 0
	echo_time stop tracing
}

ftrace_run()
{
	echo_time "going to sleep for $delay seconds"
	$WAIT_POST_TEST_CMD --timeout $delay

	ftrace_show_params

	ftrace_start
	$WAIT_POST_TEST_CMD --timeout $duration
	ftrace_stop

	touch $TMP_RESULT_ROOT/ftrace.data
	[ -n "$events" ] && upload_files -t ftrace_events $FTRACE_EVENTS_DIR/*
}
