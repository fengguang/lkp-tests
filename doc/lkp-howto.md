
#Linux Kernel Performance tests HOWTO


##Abstract

This document explains the steps of setup and running the test
suite for daily kernel development.


##Preface

This document is written to help developers run tests and get
the results on local develop machine and bring the community up
to speed on the ins and outs of the Linux Kernel Performance tests
project.


###Copyright

Refer to COPYING.


###Disclaimer

Use the information in this document at your own risk. We
disavow any potential liability for the contents of this
document. Use of the concepts, examples, and/or other content
of this document is entirely at your own risk.

All copyrights are owned by their owners, unless specifically
noted otherwise. Use of a term in this document should
not be regarded as affecting the validity of any trademark
or service mark.

Naming of particular products or brands should not be seen
as endorsements.

You are strongly recommended to take a backup of your system
before major installation and backups at regular intervals.


##Introduction


##Structure


##Writing Tests

In general, we can sum up to three steps to write a simple test
on our infrastructure.

Let's describe step by step with an example: ebizzy.

- Create a package maker script.

 The package maker script should follow the main package maker
 infrastructure. Look into the "pack/default" to see if the
 default method "download(), build(), install(), pack() and
 cleanup()" can fit the new benchmark. If yes, just set some
 variables like the benchmark package URL, the default method
 can use the variables to download, build, install and pack the
 benchmark to specified location. If any method is not fit, just
 write as expected with the same name, then they will cover the
 same named method in "pack/default".

 Look into "pack/ebizzy" for a example, all methods except "install()"
 are fit for ebizzy, so we only rewrite the "install()" method here.

- Write the main test case script.

 The main test case script should be placed to "tests" directory.
 Create a executable script and write the benchmark running process in.
 Note that the parameters should be declared at the top of the script
 like following from "tests/ebizzy":

		#!/bin/sh
		# - nr_threads
		# - duration
		# - iterations

 The next step is writing a jobfile for the new created test case script
 under "jobs" directory so that we can easily testing new parameters by
 just changing the yaml formated jobfile.

 See the example of "jobs/ebizzy.yaml":

		testcase: ebizzy  <= test case name, the same with test script name

		nr_threads: 200%  <= parameter, be parsed with setup/nr_threads
		iterations: 100x  <= parameter, be parsed with setup/iterations

		ebizzy:
		  duration: 10s   <= parameter, be parsed by test script self

- Write the test case result parser.

 While after running, the benchmark will generate result, and we should know
 how to use the result. The scripts under "stats" directory will do the result
 parse for each test case. The parser script should convert the general output
 of the test case script to a json format result, so that we can use the json
 format result to do some comparation. We can find and compute all the data useful
 and comparable for us like failure or not, throughput, any average, stddev and so on.

 See an example of ebizzy output and parsed json result:

		# cat /result/ebizzy/25%-2x-3s/debian/debian/defconfig/4.0.0-1-amd64/0/ebizzy
		Iteration: 1
		2015-06-17 16:10:33 ./ebizzy -t 2 -S 3
		21026 records/s 10515 10510
		real  3.00 s
		user  2.07 s
		sys   3.94 s
		Iteration: 2
		2015-06-17 16:10:36 ./ebizzy -t 2 -S 3
		21348 records/s 10675 10672
		real  3.00 s
		user  1.96 s
		sys   4.05 s


		# cat /result/ebizzy/25%-2x-3s/debian/debian/defconfig/4.0.0-1-amd64/0/ebizzy.json
		{
		  "ebizzy.throughput": [
		    21026,
		    21348
		  ],
		  "ebizzy.throughput.per_thread.min": [
		    10510,
		    10672
		  ],
		  "ebizzy.throughput.per_thread.max": [
		    10515,
		    10675
		  ],
		  "ebizzy.throughput.per_thread.stddev_percent": [
		    0.011890040901740702,
		    0.0070264193367060145
		  ],
		  "ebizzy.time.real": [
		    3.0,
		    3.0
		  ],
		  "ebizzy.time.user": [
		    2.07,
		    1.96
		  ],
		  "ebizzy.time.sys": [
		    3.94,
		    4.05
		  ]
		}

##Testing

Better to use a Debian system to run the tests in order to get more
accurate results and reduce strange errors since it was developed
based on a Debian system.

Preinstall necessary packages:

	# apt-get install ruby

For now Debian based distros are required.

###Split job file

Use split-job command to split the predefined job file.

	# ./sbin/split-job -h
	Usage: split-job [options] jobs...

	options:
	    -o, --output PATH                output path
	    -c, --config CONFIG              test kernel config
	    -k, --kernel COMMIT              test kernel commit
	    -h, --help                       show this message

Here use the '-c' option to specify the kconfig of the testing kernel, if
omitted, it will be set to "defconfig" in the following setup-local step.
And the '-k' option can specify the commit number or the version of the
testing kernel, if omitted, it will be set to the local kernel version in
the following setup-local step.


###Setup local environment

Use setup-local command to configure local test environment.

	# ./bin/setup-local -h
	Usage: setup-local [options] <script>/<jobfile>

	options:
	        --hdd partition              HDD partition for IO tests
	        --ssd partition              SSD partition for IO tests
	    -h, --help                       Show this message

It is easy to understand the options '--hdd' and '--ssd'. While the argument
"script" means the scripts path under the directories "monitors",
"pack", "setup" and "tests". And "jobfile" means the generated job files path
we split from above split-job command.

This setup-local command will prepare the environment for the following test
running. The preparation contains creating the necessary directories,
installing the dependent packages, making and extracting the relevant
benchmarks, etc.

After this step, there will be a configuration file under "hosts" directory
named with local hostname. For example, my hostname is "allen", then content
of this file may be like this:

	# cat hosts/allen
	memory: 8G
	hdd_partitions: /dev/sdc2
	ssd_partitions:

Note that you may need to set environment variable

	# export LINUX_GIT=/path/to/linux/kernel/repo

in order to run some of the commands.

###Run job

Use run-local command to run a test job.

	# ./bin/run-local -h
	Usage: run-local [--dry-run] [-o RESULT_ROOT] JOBFILE
	...

The argument "JOBFILE" above is one of the job files split from split-job
command we described in 5.1. If the result root is not specified using
'-o' option here, the running result will be placed to "/result" directory.

###Example

Here, we give an example how to run a specific testcase ebizzy following
above steps.

- split the job file:

		# ./sbin/split-job jobs/ebizzy.yaml
		jobs/ebizzy.yaml => ./ebizzy-200%-100x-10s.yaml

- setup the local environment:

		# ./bin/setup-local ./ebizzy-200%-100x-10s.yaml

- run the generated job file:

		# ./bin/run-local ./ebizzy-200%-100x-10s.yaml

Then the running result will be placed at '/result'.

Which can be listed by command

	# ./sbin/lkp rt ebizzy
