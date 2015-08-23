#!/usr/bin/env ruby
LKP_SRC ||= ENV['LKP_SRC']

DEVEL_HOURLY_KCONFIGS = ['x86_64-rhel']

KERNEL_ROOT = '/pkg/linux'

BOOT_TEST_CASE = 'boot'
DMESG_BOOT_FAILURES_STAT_KEY = 'dmesg.boot_failures'
