#!/usr/bin/gnuplot

set term png size 1024,768
set output "output.png"
set yrange [-1:5000]

plot "multi-bench-0.plot" title "Instance-1", \
     "multi-bench-1.plot" title "Instance-2", \
     "multi-bench-2.plot" title "Instance-3", \
     "multi-bench-3.plot" title "Instance-4", \
     "multi-bench-4.plot" title "Instance-5"
