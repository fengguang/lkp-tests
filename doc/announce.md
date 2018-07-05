0-day kernel build/boot testing farm
====================================

(June 2012 MSR by Fengguang Wu <fengguang.wu@intel.com>)

the problem
-----------

The linux kernel has a vibrant community and fast development cycles, which is
excellent. On the other hand, the large changesets carry bugs and regressions.
Judging by the pains that me as a typical kernel developer encountered in the
daily hacking, there are a lot improvements to be desired.

Build errors are often regarded as trivial ones. However we obviously lack an
effective way to prevent many of them from leaking into Linus' tree, not to
mention the linux-next tree, where it hurts many -mm developers.

According to Geert's "Build regressions/improvements in v3.4" report, there are
~100 known build bugs shipped with the official Linux 3.4 release. The numbers
are somehow exaggerated because it contains build failures for many less-cared
archs, but that fact still stroked me.

The attached xfs.png and drm.png represent my initial build status for the
typical dev trees. Each red 'c' character indicates one commit that won't build
for one kconfig. A line full of 'c' indicates one build bug inherited from the
base tree (ie. Linus' tree); a range of 'c' characters mean a build error is
introduced and fixed _some time_ later, which will be a problem for bisects.

Runtime oopses are more challenging. As you may discover in LKML, lots of the
bug reports are simply ignored, because it's often really hard to track down
user reported problems. Hard-to-reproduce bugs are virtually not fixable; bugs
for old kernels are not cared by upstream developers; regressions not bisected
down to one particular commit could kill quite some brain cells, and there is
the question "who is to blame for^W^Wown this bug?". To be frank, the only way
to guarantee the prompt fix of a bug is to explicitly tell the developer: hi,
your XXX commit triggered this YYY bug.

It boils down to one question: How can we make sure every regressions are
caught, root caused and fixed in some timely and easy fashion? There are lots
of works to do in each development stage, and the part of problem I'm trying
to attack is: quality assurance in the very early development stage, as soon as
new commits are pushed to public git trees.

0-day kernel build test farm
----------------------------

In order to effectively improve Linux kernel quality and fuel its R&D cycles,
I'm setting up this 0-day kernel build test farm with highlights:

0. 0 efforts to use
1. 1-hour response time (aka. 0-day)
2. "brute-force" commit-by-commit tests
3. auto test all branches in all developers' git trees
4. automated error notification to the right developer

### 0 efforts to use

We need to encourage, but NOT rely on the developers' self-descipline to do
tests on their own. I noticed that even the most seasoned maintainers who
manage their own professional build tests may act carelessly at times and push
untested commits publicly. IMHO this is human nature that we need to face
rather than blame. Then there are the more typical developers who only build
and run their kernels for one config and hardware. We have to accept that not
every one will bother or have the time/resources to carry out thorough tests.

So the most effective way for quickly improving Linux quality would be to run
a test farm that works 7x24 on all the new commits. I'm not trying sell shiny
test tools to the kernel developers (at least, it's not the NO.1 goal), but
rather take on efforts to set up and maintain one test farm and make it
perform well.

The kernel developers are delighted to find that, all of a sudden, they are
backed by a professional build testing system. The responses have mostly been
positive, and the few negative ones did help improve the system.

### 1-hour response time (aka. 0-day)

This is indeed a very important and possible target. It creates excellent user
experiences, makes the developers feel like at home because they can hardly do
better even when kicking off tests on their own machines. It makes Intel look
good, professional and powerful, and brings Intel very close to the community.

Quite a few developers (including myself) overuse linux-next as their catch-all
testbed..even for the silly build errors. linux-next is re-assembled and tested
on a daily basis and I'm trying to outrace it and get errors notified/fixed
before the linux-next merge.

### auto test all branches in all developers' git trees

There are nice tools to help developers to do in-house tests; there are well
established build farms that work daily on the linux-next tree. However, there
is still one big gap lying in between: the various dev branches inside the
various git trees asks for more 3rd party testing.

Our test farm will auto grab all newly created or updated branches and make
sure every new piece of works are properly tested, hopefully before being
merged by linux-next as well as the non-rebaseable Linus/tip/net etc. upstream
trees.

### "brute-force" commit-by-commit tests

It's a common expectation for the developers to do bisectibility tests, however
there have been no way to *ensure* this. Perhaps, it was deemed impossible for
some central server(s) to carry out bisectibility tests for all the 10000+
commits merged in one Linux release. However, my experiments show that, by
taking advantage of some optimizations, it only requires one single 2-socket
SandyBridge server to do basic build tests for each and every commit. And
adding more servers will further improve the test coverage and response time.

The most important caveat is, if it takes half hour to build the 1st commit from
scratch, the following 10 commits (as incremental changes) typically only takes
another half hour to compile. In that sense, it's not really 'brute-force'
compilations. Considering the guarantees of bisectibility and the ability to
find out the right developer to notify, the cost is well deserved.

### automated error notification to the right developer

Compile errors are trivial ones after all. They are best suitable for automation.
That helps guarantee the response time: once human checks are involved, the added
delays will be unpredictable. And it will help reduce long term maintenance cost.

current status
--------------

We are running two 2-socket SandyBridge compile servers. They build 300-400
commits and ~10000 kernels per day. 30 kconfigs are tested for each commit.

We are "routinely" catching 1-2 new build error(s) on each working day.  New
build warnings and sparse check warnings are also discovered on a daily basis.

Most of the built kernels will be boot tested. The supporting hardwares are
several less powerful boxes, each runs 4-12 kvm instances, each can boot test a
kernel in about 1 minute. Once boot up, some heavier tests on memory management,
I/O and trinity fuzzer will be selectively executed. This system is proved to
be good at catching runtime errors. For example, here is the list of bug
reports I sent:

	11372 N F Jun 22 Cc LKML         ( 200:0) &-&->Re: boot hang on commit "PM / ACPI: Fix suspend/resume regression caused by cpuidle cleanup."
	11995 N F Jun 23 Cc LKML         ( 101:0) BUG: tracer_alloc_buffers returned with preemption imbalance
	12141 N F Jun 24 Cc LKML         (  39:0) boot hang on CONFIG_FB_VGA16
	12142   F Jun 24 Cc LKML         (  77:0) vfs/for-next: NULL pointer dereference in sysfs_dentry_delete()
	  606   F Jun 25 To Joern Engel  (  71:0) NULL dereference in logfs_get_wblocks()
	13017 N F Jun 26 Cc LKML         ( 106:0) BUG: No init found on NFSROOT
	13019   F Jun 27 Cc LKML         (  90:0)   `-> BUG: held lock freed!

	  534   F Jul 03 Cc LKML         (  44:0) genirq: Flags mismatch irq 4. 00000000 (serial) vs. 00000000 (lirc_sir)
	  539   F Jul 03 Cc LKML         (7640:2) [mac80211-next:for-john] WARNING: at /c/kernel-tests/net/net/wireless/core.c:471 wiphy_register+0
	  606 r F Jul 06 Cc LKML         ( 351:1) general protection fault on ttm_init()
	  626   F Jul 08 Cc LKML         (3047:2) WARNING: __GFP_FS allocations with IRQs disabled (kmemcheck_alloc_shadow)
	  645 r F Jul 09 Cc LKML         (3324:2) rcu_dyntick and suspicious RCU usage
	  659   F Jul 10 Cc LKML         (5418:2) [kgdb:kgdb-next] KGDB: BP remove failed: ffffffff81026ed0
	  662   F Jul 10 Cc LKML         (5019:2) [Staging/speakup] BUG: spinlock trylock failure on UP on CPU#0, trinity-child0/484
	  663   F Jul 10 Cc LKML         (2999:2) linux-next: Early crashed kernel on CONFIG_SLOB
	  664   F Jul 10 Cc LKML         (3068:2) Kernel boot hangs on commit "switch fput to task_work_add"
	  665   F Jul 10 To LKML         (3643:2) isdnloop: stack-protector: Kernel stack is corrupted in: ffffffff81e5b55b
	  666   F Jul 10 Cc LKML         (4748:2) ftrace_ops_list_func() triggered WARNING: at kernel/lockdep.c:3506
	  667   F Jul 11 Cc LKML         (2769:2) WARNING: at drivers/misc/kgdbts.c:813 run_simple_test()

The pile of bug reports around July 10 are some aged bugs found by the newly
setup randconfig boot tests. Besides, I didn't send out two machine specific
bugs, which we may need to resolve on ourselves.

It's been hard time for me to bring these tests up. However it seemed to pay
off. The initial number of bugs they exposed indicates they will be effective
in catching new regressions in the future.

summary
-------

Hopefully this will be a valuable long term project for the Linux community as
well as Intel. We are probably the best candidate to run these tests, not only
because hardware is cheap for Intel, but also that we are in the unique position
that have all the bleeding edge hardwares to test run the new kernels, and are
actually the most willing to make sure they fit well with each other.

Thanks,
Fengguang
