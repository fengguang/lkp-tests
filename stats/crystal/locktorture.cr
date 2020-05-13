#!/usr/bin/env crystal

# The result line in input is in format:
# [time] $type-torture:--- End of test: $result: arg=value arg=value ...
#
# $type and $result are essential for a test.
# And for now, we care about the value of arg onoff_interval
# which represents doing cpuhotplugs or not.
#
# 'LOCK_HOTPLUG' and 'FAILURE' both represent the test failed.
# but there is a problem:
# there's a bug in torture test code, so hotplug can't be considered as failure.
# and another patch is needed to use '.lock_hotplug',so remain the '.lock_hotplug'.
# finally after discussing uniform the output of stat:
# keep all it`s original state
# and we know 4 states temporaryly: success, success [debug], failure, lock_hotplug
#
# Input example:
# [  416.167904] spin_lock-torture:--- End of test: LOCK_HOTPLUG: nwriters_stress=4
#  nreaders_stress=0 stat_interval=60 verbose=1 shuffle_interval=3 stutter=5 shutdown_secs=0 onoff_interval=3 onoff_holdoff=30

result = "unknown"
type = "unknown"
cpuhotplug = false

while (line = STDIN.gets)
  case line
  when /^\[.*\] ([A-Za-z_]+)-torture.*End of test: (.*):.*onoff_interval=([0-9]+).*/
    type = $1
    result = ($2.downcase.delete " ").gsub("[debug]", "")
    cpuhotplug = true unless $3 == "0"
    break
  end
end

stat = (cpuhotplug ? "cpuhotplug-" : "") + type + "." + result
puts "#{stat}: 1"
