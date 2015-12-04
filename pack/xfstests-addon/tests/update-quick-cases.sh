#!/bin/bash

# after upgrading xfstests,
# - run this script to add new cases to $1-quick
# - queue jobs
# - adjust the cases grouping based on the test results' run time (rebalance)
#   or failure status (identify broken cases, either fix it up or move to the
#   $1-broken group)
# - each finalized group should ideally have 10-30m total runtime

[[ $1 ]] || exit

mv $1-quick .$1-quick
ls $1/??? | grep -v -f <(cat $1-*) | cut -f2 -d/ > $1-quick
