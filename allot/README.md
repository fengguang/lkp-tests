## Job Allocation

This disk layout defines a number of job allocation schemes.

The format is

	allot/$scheme/$testbox/$jobfile

A tree example:

```
	allot
	├── cyclic
	│   ├── brickland1
	│   │   ├── aim7-micro.yaml
	│   │   ├── hpcc.yaml -> ../../../jobs/hpcc.yaml
	│   │   ├── idle.yaml -> ../../../jobs/idle.yaml
	│   │   ├── pigz.yaml -> ../../../jobs/pigz.yaml
	│   │   └── will-it-scale.yaml -> ../../../jobs/will-it-scale.yaml

	├── diag
	│   ├── brickland1
	│   │   └── will-it-scale.yaml -> ../../../jobs/will-it-scale.yaml
	│   ├── brickland3
	│   │   └── aim7-micro.yaml

	├── rand
	│   ├── vm-kbuild-1G
	│   │   └── xfstests-generic.yaml -> ../../../jobs/xfstests-generic.yaml

	├── scsi
	│   └── vm-kbuild-4G
	│       ├── xfstests-btrfs.yaml -> ../../../jobs/xfstests-btrfs.yaml
	│       ├── xfstests-ext4.yaml -> ../../../jobs/xfstests-ext4.yaml
	│       ├── xfstests-generic.yaml -> ../../../jobs/xfstests-generic.yaml
	│       └── xfstests-xfs.yaml -> ../../../jobs/xfstests-xfs.yaml
	├── scsi:fixes -> scsi
	└── scsi:misc -> scsi
```


The allocation scheme may be referenced by the queue command

	$ queue $scheme

For example,

```
	$ queue scsi
```

will queue the 4 xfstests jobs to testbox vm-kbuild-4G.


## Job Allocation Schemes

- cyclic

  Whenever a testbox's cyclic queue goes empty, it will be auto refilled with
  the set of jobs defined in this scheme.

  It should ideally assign the same amount of works (e.g. 1 day) to each testbox.
  The same job will be assigned to multiple testboxes of different hardware
  generations.

- diag

  Suitable for evaluating a patchset that can potentially impact many different
  kind of workloads.

```
	$ queue diag -b linux-next
```

  It should normally assign one job (or multiple quick jobs) to each testbox.

- rand

  The jobs defined here will be randomly selected for testing new kernels.
  Since the new kernels may be unstable, only virtual machines are defined.

- tree:branch

  The unit test schemes. Whenever the git tree/branch is updated, jobs defined
  here will be auto queued and results will be emailed to the branch committer.

