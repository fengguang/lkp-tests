#########################################################
# CAUTION: For constants shared between shell and ruby
#          Be careful to write code compatible with shell
#          and ruby!!!
#########################################################

##
## Errno
##

ERR_SUCCESS=0
ERR_ASYNC=12
ERR_INVALID_COMMIT=13
ERR_INVALID=14		# Invalid argument
ERR_UNSUPPORTED=15	# Unsupported feature
ERR_TIMEOUT=16		# Timed out
ERR_UNKNOWN=127		# Unknown error

##
## Other
##

KERNEL_ROOT='/pkg/linux'

BOOT_TEST_CASE='boot'
DMESG_BOOT_FAILURES_STAT_KEY='dmesg.boot_failures'
