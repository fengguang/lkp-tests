Linux Kernel Performance tests
==============================

Getting started
---------------

	git clone git://git.kernel.org/pub/scm/linux/kernel/git/wfg/lkp-tests.git

	cd lkp-tests
	export LKP_SRC=$PWD
	export PATH=$PATH:$LKP_SRC/bin

	lkp help

Install packages for a job
--------------------------

	# browse and select a job you want to run, for example, jobs/hackbench.yaml
	ls $LKP_SRC/jobs
	lkp install $LKP_SRC/jobs/hackbench.yaml

Run one atomic job
------------------

	lkp split-job $LKP_SRC/jobs/hackbench.yaml
	# output is:
	# jobs/hackbench.yaml => ./hackbench-1600%-process-pipe.yaml
	# jobs/hackbench.yaml => ./hackbench-1600%-process-socket.yaml
	# jobs/hackbench.yaml => ./hackbench-1600%-threads-pipe.yaml
	# jobs/hackbench.yaml => ./hackbench-1600%-threads-socket.yaml
	# jobs/hackbench.yaml => ./hackbench-50%-process-pipe.yaml
	# jobs/hackbench.yaml => ./hackbench-50%-process-socket.yaml
	# jobs/hackbench.yaml => ./hackbench-50%-threads-pipe.yaml
	# jobs/hackbench.yaml => ./hackbench-50%-threads-socket.yaml

	lkp run ./hackbench-50%-threads-socket.yaml

Check result
------------

	lkp result hackbench

