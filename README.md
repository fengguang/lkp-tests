# Linux Kernel Performance tests

## Getting started

```
	git clone https://github.com/01org/lkp-tests.git

	cd lkp-tests
	make install

	lkp help
```

## Install packages for a job

```
	# browse and select a job you want to run, for example, jobs/hackbench.yaml
	ls lkp-tests/jobs
	lkp install lkp-tests/jobs/hackbench.yaml
```

## Run one atomic job

```
	lkp split-job lkp-tests/jobs/hackbench.yaml
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
```

## Check result
```
	lkp result hackbench
```

## Supported Distributions

Most test cases should install/run well in

- Debian sid
- Ubuntu 14.04
- Archlinux

There is however some initial support for:

- OpenSUSE:
	- jobs/trinity.yaml
- Fedora

As for now, lkp-tests still needs to run as root.

## Adding distribution support

If you want to add support for your Linux distribution you will need
an installer file which allows us to install dependencies per job. For
examples look at: distro/installer/* files.

Since packages can have different names we provide an adaptation mapping for a
base Ubuntu package (since development started with that) to your own
distribution package name, for example adaptation files see:
distro/adaptation/*. For now adaptation files must have the architecture
dependent packages (ie, that ends with the postfix :i386) towards the end
of the adaptation file.

You will also want to add a case for your distribution on sync_distro_sources()
on the file lib/install.sh.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
