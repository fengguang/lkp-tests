#!/usr/bin/python
# summarize PT trace function call times
# make sure to run both reporting and collection as root
# total kernel tracing:
# perf record -e intel_pt/cyc_thresh=5,cyc=1/ -a sleep X
# you can experiment with the cyc_thresh value. the lower the more accurate timing, but also much bigger traces
#
# or for scheduler only tracing (most of the scheduler, some parts not included)
# perf record -e intel_pt/cyc_thresh=5,cyc=1/k --filter 'filter sys_getgroups / pm_qos_request filter __schedule / schedule' -a sleep X
#
# perf script --ns --itrace=cr -F cpu,ip,time,sym,flags,addr,symoff | pt-call-summary.py
# additional reporting:
# perf report  --itrace=i1usg --stdio		   get caller/callee tree
# perf report  --itrace=i1usg --stdio --no-children     get caller/callee tree, reversed
#
# to look at detailed traces for timestamps:
# look at time stamp and P in time stamp table
# function calls:
# perf script -C <P> --ns --itrace=cr --time <TIME-STAMP> -F cpu,ip,time,sym,flags,addr,symoff
# assembler traces:
# perf script -C <P> --ns --itrace=i0ns --time <TIME-STAMP> -F cpu,ip,time,sym,flags,addr,symoff,insn | ./xed -A -64 -F insn: 
#

# Copyright (c) 2017, Intel Corporation
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.

columns = """
RUN      total time duration, excluding callees (us)
OUTS     duration of callees outside of filter region (us)
CALLEE   duration of callees (us)
TOTAL    duration of function including callees (us)
TOTA     average total (us)
NUM      number of calls
PCT-TOT  percentage of dur compared to total time
NAME     function name

n-TOT    n% percentile of total duration of function, including callees
n-DUR    n% percentile of total duration of function, including callees
n-TIME   perf time stamp at n% percentile of duration (to pass to --time)
P	 CPU at n% percentile of duration (to pass to -C)
"""

import sys
import collections
import argparse
import re
import os

# [000] 255625.614382717:   tr strt		     0 [unknown] => ffffffff810dc9a0 sched_clock_cpu+0xVV
# [000] 255625.614382717:   call	 ffffffff810dca2e sched_clock_cpu+0xVV =>		0 [unknown]
# [000] 255625.614382722:   tr strt		     0 [unknown] => ffffffff810dca33 sched_clock_cpu+0xVV
# [000] 255625.614382722:   return       ffffffff810dca3d sched_clock_cpu+0xVV =>		0 [unknown]

ap = argparse.ArgumentParser()
ap.add_argument('--all', action='store_true', help="Print duration for every call")
ap.add_argument('--debug', action='store_true', help="Extra debugging output")
ap.add_argument('--tracefunc', default=None, help="Print all updates for function (for debugging)")
ap.add_argument('--thresh', type=float, default=0.05, help="Min threshold to print")
ap.add_argument('--max-print', default=20, help="Max number of parse errors to print")
ap.add_argument('--filter', default=None, help="Only account callees of function")
ap.add_argument('--binary', default=None, help="Binary to resolve out of context branches")
args = ap.parse_args()

special_exit = {
    "__schedule": "schedule_tail",
    "schedule": "schedule_tail",
}

# handle symbols that don't have clear call/ret (usually assembler)
# collapse the resulted symbols into one
def fixup_sym(s):
    if s.startswith("entry_SYSCALL") or s.startswith("retint_"):
	return "entry_SYSCALL"
    if s.startswith("__switch_to"):
	return "__switch_to"
    return s

def parse_sym(s):
    n = s.split("+")
    if len(n) > 1:
	n[0] = fixup_sym(n[0])
	return n[0], int(n[1], 16)
    s = fixup_sym(s)
    return s, 0

def percentile(l, p):
    if len(l) < 2:
	return 0
    n = max(int(round(p * len(l) + 0.5)), 2)
    return l[n-2]

def debugp(s):
    if args.debug:
        print s

def read_calls(b):
    calls = dict()
    with os.popen("objdump -d " + b) as f:
        for l in f:
            if "callq" not in l:
                continue
            #  ffffffff81000007:       e8 b8 01 00 00          callq  ffffffff810001c4 <verify_cpu>
            n = l.split()
            if len(n) < 1:
                continue
            addr = int(n[0].strip(":"), 16)
            m = re.search(r'callq.*<(.*)>', l)
            if m:
                calls[addr] = m.group(1)
    return calls
        
funcstart = dict()
funclast = dict()
funccount = collections.Counter()
funcs = collections.Counter()
funcdur = collections.defaultdict(list)     # tuples of (dur, timestamp, cpu, total) 
curdur = collections.Counter()
outside = collections.Counter()
callee = collections.Counter()
callers = collections.defaultdict(set)
callee_set = collections.defaultdict(set)
outs_last_func = dict()
outs_start = dict()
last_filter_callee = dict()
last_filter_caller = dict()
last_filter_stack = collections.defaultdict(list)
ignore = dict()
outside_funcs = set()
iflag_default = True if args.filter else False
ignored = 0
parsed = 0
mismatches = 0

startt = dict()
endt = dict()

num_print = 0

def update_funcdur(f, dur, l, cpu):
    funcs[f] += dur
    curdur[(cpu, f)] += dur
    if args.debug and args.tracefunc == f:
	print l,
	print "delta", dur*10e6, "dur", funcs[f]*10e6, "callee", callee[f]*10e6

static_calls = dict()
if args.binary:
    static_calls = read_calls(args.binary)

for l in sys.stdin:
    n = l.split()
    off = 0
    if n[2] == "tr":
	off = 1
    try:
        cpu, time, cmd, fromf, tof, fromip = int(n[0].strip("[]")), float(n[1].strip(":")), n[2], n[4+off], n[7+off], int(n[3+off], 16)
    except ValueError:
	if num_print < args.max_print:
	    print "unparseable line", l,
	    num_print += 1
        ignored += 1
	continue
    parsed += 1
    fromf, fromo = parse_sym(fromf)
    tof, too = parse_sym(tof)
    if cpu not in startt:
	startt[cpu] = time
    endt[cpu] = time
    iflag = ignore.setdefault(cpu, iflag_default)
    # coming back from out of filter region
    if cmd == "tr":
        if iflag:
            if tof == args.filter:
                ignore[cpu] = False
                if args.debug:
                    print "stop ignoring at", tof
            else:
                continue
        else:
            if args.filter in special_exit and tof == special_exit[args.filter]:
                ignore[cpu] = True
                continue
        debugp("tr start " + tof)
        # XXX this may get confused if the outside region calls us first
        if fromf == "[unknown]" and cpu in last_filter_callee:
            if last_filter_caller[cpu] != tof:
                # we got called from outside while suspended on an external call
                # push on stack
                last_filter_stack[cpu].append((last_filter_callee[cpu], 
                        last_filter_caller[cpu],
                        outs_start[cpu] if cpu in outs_start else None,
                        outs_last_func[cpu] if cpu in outs_last_func else None))
                debugp("push " + last_filter_callee[cpu] + " " + last_filter_caller[cpu])
                #print time, "returning from out of context", fromf, "to", tof, "expected", last_filter_caller[cpu]
                if cpu in outs_last_func:
                    del outs_last_func[cpu]
                    del outs_start[cpu]
            else:
                fromf = last_filter_callee[cpu]
                callers[tof].add(fromf)
                callee_set[fromf].add(tof)
            del last_filter_callee[cpu]
            del last_filter_caller[cpu]
	if too != 0:
	    if (cpu, tof) in funclast:
		callee[tof] += time - funclast[(cpu, tof)]
	    if cpu in outs_start:
		if cpu in outs_last_func and outs_last_func[cpu] != tof:
		    if num_print < args.max_print:
			print l,
			print "mismatch, expected to come back to", outs_last_func[cpu], "got", tof
			num_print += 1
                    mismatches += 1
		outside[tof] += time - outs_start[cpu]
	else:
            funcstart[(cpu, tof)] = time
	    funccount[tof] += 1
        if fromf != "[unknown]" and (cpu, fromf) in funclast:
            update_funcdur(fromf, time - funclast[(cpu, fromf)], l, cpu)
	funclast[(cpu, tof)] = time
	if too == 0:
	    funcstart[(cpu, tof)] = time
        if fromf != "[unknown]" and cpu in outs_start and (cpu, fromf) in curdur:
            start = outs_start[cpu]
            funcdur[fromf].append((curdur[(cpu, fromf)], start, cpu, time - start))
    elif cmd == "call":
        if iflag:
            if tof == args.filter:
                debugp("stop ignoring at " + tof)
                ignore[cpu] = False
            else:
                continue
        debugp("call " + tof)
        orig_tof = tof
        # patch up IPs for direct calls. XXX fix decoder to do that
        if tof == "[unknown]":
            if fromip in static_calls:
                tof = static_calls[fromip]
                last_filter_callee[cpu] = tof
                last_filter_caller[cpu] = fromf
                outside_funcs.add(tof)
	funclast[(cpu, tof)] = time
	funcstart[(cpu, tof)] = time
	funccount[tof] += 1
        curdur[(cpu, tof)] = 0
	if (cpu, fromf) in funclast:
	    update_funcdur(fromf, time - funclast[(cpu, fromf)], l, cpu)
	funclast[(cpu, fromf)] = time
	callers[tof].add(fromf)
        callee_set[fromf].add(tof)
	if tof == "[unknown]":
	    outs_start[cpu] = time
	    outs_last_func[cpu] = fromf
    elif cmd == "return":
        if iflag:
            continue
        debugp("return " + fromf)
        if args.filter == fromf:
            debugp("start ignoring at " + tof)
            ignore[cpu] = True
            iflag = True
	if tof == "[unknown]":
	    outs_start[cpu] = time
	    if cpu in outs_last_func:
		del outs_last_func[cpu]
            if len(last_filter_stack[cpu]) > 0:
                # outs_start[cpu],
                # outs_last_func[cpu]
                last_filter_callee[cpu], last_filter_caller[cpu], _, _ = last_filter_stack[cpu].pop()
                if cpu in outs_last_func and outs_last_func[cpu] is None:
                    del outs_last_func[cpu]
                if cpu in outs_start and outs_start[cpu] is None:
                    del outs_start[cpu]
                debugp("pop " + last_filter_callee[cpu] + " " + last_filter_caller[cpu])
	if (cpu, fromf) not in funclast:
	    continue
	dur = time - funclast[(cpu, fromf)]
	update_funcdur(fromf, dur, l, cpu)
	if (cpu, fromf) in funcstart:
	    start = funcstart[(cpu, fromf)]
	    funcdur[fromf].append((curdur[(cpu, fromf)], start, cpu, time - start))
	    if args.all:
		print "%15.9f" % time, "%8.2f" % ((time - funcstart[(cpu, fromf)])*1e6), "\t", fromf
        if iflag:
            continue
	if (cpu, tof) in funclast:
	    callee[tof] += time - funclast[(cpu, tof)]
	if tof == args.tracefunc:
	    print l,
	    print "delta", dur, "callee", callee[tof]
	funclast[(cpu, tof)] = time

print
print "%d out of %d ignored" % (ignored, parsed)
print "%d mismatches" % mismatches
print

print columns
print

cpus = sorted(startt.keys())
print "times traced: ", " ".join(["%5.2fus" % ((endt[cpu] - startt[cpu])*1e6) for cpu in cpus])
#total = sum([endt[cpu] - startt[cpu] for cpu in cpus])*1e6
print

totalsched = sum(funcs.values())*1e6
left = []
left_outside = 0.0
print "%8s %8s %6s %8s %8s %8s %8s %8s %8s %8s %8s %-30s" % (
	"RUN", "NUM", "PCT-TO",
	"OUTS", "CALLEE", "TOTAL", "TOTAV",
	"50-DUR", "90-DUR", "95-DUR", "99-DUR", "NAME")
all_total = 0
for j in sorted(funcs, key=lambda x: funcs[x], reverse=True):
    all_total += outside[j] + callee[j] + dur
    dur = funcs[j] * 1e6
    pct = (dur/totalsched)*100. if totalsched > 0 else 0
    if pct < args.thresh:
	left.append(pct)
        left_outside += outside[j]
    else:
	sorted_p = sorted(funcdur[j], key=lambda x: x[0])
	p = [x[0] for x in sorted_p]
	print "%8.2f %8d %6.2f %8.2f %8.2f %8.2f %8.2f %8.2f %8.2f %8.2f %8.2f %-30s" % (
		    dur, funccount[j],
		    pct,
		    outside[j] * 1e6, callee[j]* 1e6,
		    dur + callee[j]*1e6 + outside[j]*1e6,
		    (dur + callee[j]*1e6 + outside[j]*1e6) / len(p) if len(p) > 0 else 0,
		    percentile(p, .50)*1e6, percentile(p, .90)*1e6,
		    percentile(p, .95)*1e6, percentile(p, .99)*1e6,
		    j + (" [O]" if j in outside_funcs else ""))
        assert sum(p) <= dur
print
print "all_total", all_total
print "sum", sum([endt[cpu] - startt[cpu] for cpu in cpus])

# debug me
#assert all_total <= sum([endt[cpu] - startt[cpu] for cpu in cpus])

left = sorted(left)
sleft = sum(left)
print "%8.2f %8d %6.2f %8.2f %8s %8s %6s %6s %6s %6s %6s %-30s" % (
	sleft, len(left),
	(sleft/totalsched)*100. if totalsched > 0 else 0,
        left_outside,
	"", "", "", "", "", "", "", "other")
print
print "%d functions below threshold" % len(left)
print

print "total percentiles"
print
print "%8s %8s %8s %8s %s" % ("50-TOT", "90-TOT", "95-TOT", "99-TOT", "NAME")
for j in sorted(funcs, key=lambda x: funcs[x], reverse=True):
    dur = funcs[j] * 1e6
    pct = (dur/totalsched)*100. if totalsched > 0 else 0
    if pct < args.thresh:
	continue
    sorted_p = sorted(funcdur[j], key=lambda x: x[3])
    p = [x[3] for x in sorted_p]
    print "%8.2f %8.2f %8.2f %8.2f %s" % (
	    percentile(p, .50)*1e6,
	    percentile(p, .90)*1e6,
	    percentile(p, .95)*1e6,
	    percentile(p, .99)*1e6,
	    j)

print
print "Callers"
print
print "%30s %-40s" % ("FUNC", "CALLERS")
for j in sorted(funcs, key=lambda x: funcs[x], reverse=True):
    dur = funcs[j] * 1e6
    pct = (dur/totalsched)*100. if totalsched > 0 else 0
    if len(callers[j]) > 0 and pct >= args.thresh:
	print "%30s %-40s" % (j, " ".join(callers[j]))
print

print
print "Callees" 
print
print "%30s %-40s" % ("FUNC", "CALLEES")
for j in sorted(funcs, key=lambda x: funcs[x], reverse=True):
    dur = funcs[j] * 1e6
    pct = (dur/totalsched)*100. if totalsched > 0 else 0
    if len(callee_set[j]) > 0 and pct >= args.thresh:
	print "%30s %-40s" % (j, " ".join(callee_set[j]))
print

def print_timestamps(title, column, ind):
    print
    print "perf timestamps of function start by " + title
    print

    print ("%8s %8s " + "%15s %8s %2s " * 4 + "%s") % (
            "RUN", "NUM",
            "50-TIME", "50-" + column, "P",
            "90-TIME", "90-" + column, "P",
            "95-TIME", "95-" + column, "P",
            "99-TIME", "99-" + column, "P",
            "NAME")
    for j in sorted(funcs, key=lambda x: funcs[x], reverse=True):
        dur = funcs[j] * 1e6
        pct = (dur/totalsched)*100. if totalsched > 0 else 0
        if pct < args.thresh:
            continue
        sorted_p = sorted(funcdur[j], key=lambda x: x[ind])
        p = [x[1] for x in sorted_p]
        pind = [x[ind] for x in sorted_p]
        pcpu = [x[2] for x in sorted_p]
        print ("%8.2f %8d " + "%15f %8.2f %2d " * 4 + " %s") % (
                dur, funccount[j],
                percentile(p, .50), percentile(pind, .50)*1e6, percentile(pcpu, .50),
                percentile(p, .90), percentile(pind, .90)*1e6, percentile(pcpu, .90),
                percentile(p, .95), percentile(pind, .95)*1e6, percentile(pcpu, .95),
                percentile(p, .99), percentile(pind, .99)*1e6, percentile(pcpu, .99),
                j)

print_timestamps("duration", "DUR", 0)
print_timestamps("total", "TOT", 3)
