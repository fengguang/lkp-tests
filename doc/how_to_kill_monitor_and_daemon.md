When a job is finished, there are several ways available in lkp-tests to
kill monitors and daemons.

There are three ways available in lkp-tests to kill deamons/monitors.
a) Kill it when task is finished
Most of daemons can be killed in this way, this is also the default way
provided in lkp-tests.
The only thing that a developer should care about is to run daemon using
"exec" to run daemon in frontend.
E.g. exec log_cmd netserver -4 -D
See daemon/netserver as an example.

b) Pending to kill it until a signal is received
If your daemon can't be run using "exec" or it has to be run in background.
You can kill it in a way like below.
E.g. setup_wait
     ./run_daemon &
	 pid=$!
	 wait_post_test
	 kill -9 "$pid"
see daemon/sockperf-server as an example

c) Kill it in a customized way
If you daemon is launched in a specail way (E.g. systemctl), the
aforementioned way may not work, you probably need to kill it in a
customized way.
E.g. cat > $TMP_RESULT_ROOT/post-run.$daemon <<EOF
       your_kill_command
EOF
See daemon/httpd as an example
