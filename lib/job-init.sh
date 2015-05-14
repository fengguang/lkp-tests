job_redirect_stdout_stderr()
{
	ln -s /usr/bin/tail /bin/tail-to-lkp

	tail-to-lkp -n 0 -f /tmp/stdout > $TMP/stdout &
	tail-to-lkp -n 0 -f /tmp/stderr > $TMP/stderr &

	tail-to-lkp -n 0 -f /tmp/stdout /tmp/stderr > $TMP/output &
}

# per-job initiation; should be invoked before run a job
job_init()
{
	export TMP=/tmp/lkp
	mkdir -p $TMP
	rm -fr $TMP/*

	cp /proc/uptime $TMP/boot-time

	job_redirect_stdout_stderr
}
