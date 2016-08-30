#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']
require "#{LKP_SRC}/lib/yaml.rb"

# /c/linux% git grep '"[a-z][a-z_]\+%d"'|grep -o '"[a-z_]\+'|cut -c2-|sort -u
LINUX_DEVICE_NAMES = IO.read("#{LKP_SRC}/etc/linux-device-names").split("\n")
LINUX_DEVICE_NAMES_RE = /\b(#{LINUX_DEVICE_NAMES.join('|')})\d+/

require "fileutils"
require "tempfile"

# dmesg can be below forms
# [    0.298729] Last level iTLB entries: 4KB 512, 2MB 7, 4MB 7
# [    8.898106] system 00:01: [io  0x0400-0x047f] could not be reserved
class DmesgTimestamp
	include Comparable

	attr_reader :timestamp

	def initialize(line)
		match = line.match(/.*\[ *(?<timestamp>\d{1,6}\.\d{6})\]/)
		@timestamp = match && match[:timestamp]
	end

	def valid?
		@timestamp != nil
	end

	def <=>(other)
		return 0 unless self.valid? || other.valid?
		return -1 unless self.valid?
		return 1 unless other.valid?

		@timestamp.to_f <=> other.timestamp.to_f
	end

	def to_s
		@timestamp
	end

	# put this functionality inside DmesgTimestamp class for now
	# below patterns are required to match in order to detect
	# abnormal sequence that indicates a possible reboot
	# LARGE timestamp
	# LARGE timestamp
	# LARGE timestamp
	# SMALL timestamp
	# SMALL timestamp
	# SMALL timestamp
	class AbnormalSequenceDetector
		def initialize
			@large_dmesg_timestamps = []
			@small_dmesg_timestamps = []
		end

		# dmesg "[ 0.000000]\n[ 1.000000]\n[ 1.000000]\n[ 2.000000]\n
		#        [ 0.000000]\n[ 0.100000]\n[ 0.200000]" is abnormal
		# dmesg "[ 0.000000]\n[ 1.000000]\n[ 1.000000]\n[ 2.000000]\n[ 1.000000]\n
		#        [ 0.100000]\n[ 0.200000]\n[ 0.300000]" is abnormal
		# dmesg "[ 0.000000]\n[ 1.000000]\n[ 0.000000]\n[ 2.000000]\n[ 1.000000]\n
		#        [ 0.100000]\n[ 0.200000]\n[ 0.300000]" is normal
		def detected?(line)
			dmesg_timestamp = DmesgTimestamp.new(line)
			if dmesg_timestamp.valid?
				if @large_dmesg_timestamps.size < 3 || @large_dmesg_timestamps.any? {|large_dmesg_timestamp| large_dmesg_timestamp <= dmesg_timestamp}
					@large_dmesg_timestamps.push(dmesg_timestamp)
					@large_dmesg_timestamps = @large_dmesg_timestamps.drop(1) if @large_dmesg_timestamps.count > 3

					@small_dmesg_timestamps.clear
				else
					@small_dmesg_timestamps.push(dmesg_timestamp)
				end
			end

			@small_dmesg_timestamps.count >= 3
		end
	end
end

def fixup_dmesg(line)
	line.chomp!

	# remove absolute path names
	line.sub!(%r{/kbuild/src/[^/]+/}, '')

	line.sub!(/\.(isra|constprop|part)\.[0-9]+\+0x/, '+0x')

	# break up mixed messages
	case line
	when /^<[0-9]>/
	when /^(kern  |user  |daemon):......: /
	when /(.+)(\[ *[0-9]{1,6}\.[0-9]{6}\] .*)/
		line = $1 + "\n" + $2
	end

	return line
end

def fixup_dmesg_file(dmesg_file)
	tmpfile = Tempfile.new '.fixup-dmesg-', File.dirname(dmesg_file)
	dmesg_lines = []
	File.open(dmesg_file, 'rb') do |f|
		f.each_line { |line|
			line = fixup_dmesg(line)
			dmesg_lines << line
			tmpfile.puts line
		}
	end
	tmpfile.chmod 0664
	tmpfile.close
	FileUtils.mv tmpfile.path, dmesg_file, :force => true
	return dmesg_lines
end

# "grep -B1 | grep -v" to get the functions called by them,
# which will hopefully be stable and representive.
CALLTRACE_COMMON_CONTEXT = "
	do_one_initcall|
	do_basic_setup|
	kernel_init_freeable|
	kernel_init|
	kthread|
	kernel_thread|
	process_one_work|
	notifier_call_chain|
"

CALLTRACE_PATTERN = /(
	#{CALLTRACE_COMMON_CONTEXT}
	SyS_[a-z0-9_]+
)\+0x/x

CALLTRACE_IGNORE_PATTERN  = /(
	#{CALLTRACE_COMMON_CONTEXT}
	worker_thread|
	warn_slowpath_.*
)\+0x/x

OOM1='invoked oom-killer: gfp_mask='
OOM2='Out of memory and no killable processes...'

def grep_crash_head(dmesg_file)
	if dmesg_file =~ /\.xz$/
		grep = 'xzgrep'
		cat = 'xzcat'
	else
		grep = 'grep'
		cat = 'cat'
	end

	raw_oops = %x[ #{grep} -a -E -e \\\\+0x -f #{LKP_SRC}/etc/oops-pattern #{dmesg_file} |
			 grep -v -E -f #{LKP_SRC}/etc/oops-pattern-ignore ]

	return {} if raw_oops.empty?

	oops_map = {}

	oops_re = load_regular_expressions("#{LKP_SRC}/etc/oops-pattern")
	prev_line = nil
	has_oom = false

	add_one_calltrace = lambda do |line|
		break if has_oom
		break if line =~ CALLTRACE_IGNORE_PATTERN
		break unless line =~ />\] ([a-zA-Z0-9_.]+)\+0x[0-9a-fx\/]+/
		oops_map["calltrace:" + $1] ||= line
	end

	raw_oops.each_line do |line|
		if line =~ oops_re
			oops_map[$1] ||= line
			has_oom = true if line.index(OOM1)
			has_oom = true if line.index(OOM2)
			next
		end

		# Call Trace:
		if line.index '+0x'
			if line.index ' ? '
				next
			end

			if line =~ CALLTRACE_PATTERN
				add_one_calltrace[prev_line] unless line.index('SyS_')
				add_one_calltrace[line]
				prev_line = nil
			else
				prev_line = line
			end

			next
		end

		$stderr.puts "oops pattern mismatch: #{line}"
	end

	return oops_map
end

def grep_printk_errors(kmsg_file, kmsg)
	return '' if ENV.fetch('RESULT_ROOT', "").index '/trinity/'
	return '' unless File.exist?('/lkp/printk-error-messages')

	if kmsg_file =~ /\.xz$/
		grep = 'xzgrep'
	else
		grep = 'grep'
	end

	if kmsg_file =~ /\bkmsg\b/
		# the kmsg file is dumped inside the running kernel
		oops = `#{grep} -a -E -e '^<[0123]>' -e '^kern  :(err   |crit  |alert |emerg ): ' #{kmsg_file} |
			sed -r 's/\\x1b\\[([0-9;]+m|[mK])//g' |
			grep -a -v -E -f #{LKP_SRC}/etc/oops-pattern |
			grep -a -v -F -f #{LKP_SRC}/etc/kmsg-blacklist`
	else
		# the dmesg file is from serial console
		oops = `#{grep} -a -F -f /lkp/printk-error-messages #{kmsg_file} |
			grep -a -v -E -f #{LKP_SRC}/etc/oops-pattern |
			grep -a -v -F -f #{LKP_SRC}/etc/kmsg-blacklist`
		oops += `grep -a -E -f #{LKP_SRC}/etc/ext4-crit-pattern	#{kmsg_file}` if kmsg.index 'EXT4-fs ('
		oops += `grep -a -E -f #{LKP_SRC}/etc/xfs-alert-pattern	#{kmsg_file}` if kmsg.index 'XFS ('
		oops += `grep -a -E -f #{LKP_SRC}/etc/btrfs-crit-pattern #{kmsg_file}` if kmsg.index 'btrfs: '
	end
	oops
end

def common_error_id(line)
	line = line.chomp
	line.gsub! /\b3\.[0-9]+[-a-z0-9.]+/, '#'			# linux version: 3.17.0-next-20141008-g099669ed
	line.gsub! /\b[1-9][0-9]-[A-Z][a-z]+-[0-9]{4}\b/, '#'		# Date: 28-Dec-2013
	line.gsub! /\b0x[0-9a-f]+\b/, '#'				# hex number
	line.gsub! /\b[a-f0-9]{40}\b/, '#'				# SHA-1
	line.gsub! /\b[0-9][0-9.]*/, '#'				# number
	line.gsub! /#x\b/, '0x'
	line.gsub! /[\\"$]/, '~'
	line.gsub! /[ \t]/, ' '
	line.gsub! /\ \ +/, ' '
	line.gsub! /([^a-zA-Z0-9])\ /, '\1'
	line.gsub! /\ ([^a-zA-Z])/, '\1'
	line.gsub! /^\ /, ''
	line.gsub! /\  _/, '_'
	line.gsub! /\ /, '_'
	line.gsub! /[-_.,;:#!\[\(]+$/, ''
	line
end

=begin
# <4>[  256.557393] [ INFO: possible circular locking dependency detected ]
 INFO_possible_circular_locking_dependency_detected: 1
=end

def oops_to_bisect_pattern(line)
		words = line.split
		return '' if words.empty?
		patterns = []
		words.each { |w|
			case w
			when /([a-zA-Z0-9_]+)\.(isra|constprop|part)\.[0-9]+\+0x/
				patterns << $1
				break
			when /([a-zA-Z0-9_]+\+0x)/, /([a-zA-Z0-9_]+=)/
				patterns << $1
				break
			when /[^a-zA-Z\/:._-]/
				patterns << '.*' if patterns[-1] != '.*'
			else
				patterns << w
			end
		}
		patterns.shift while patterns[0] == '.*'
		patterns.pop   if patterns[-1] == '.*'
		patterns.join(' ')
end

def analyze_error_id(line)

	line = line.sub(/^(kern  |user  |daemon):......: /, '')
	line.sub!(/^[^a-zA-Z]+/, '')
	# line.sub!(/^\[ *[0-9]{1,6}\.[0-9]{6}\] )/, '') # the above pattern includes this one

	case line
	when /(INFO: rcu[_a-z]* self-detected stall on CPU)/,
	     /(INFO: rcu[_a-z]* detected stalls on CPUs\/tasks:)/
		line = $1
		bug_to_bisect = $1
	when /(BUG: unable to handle kernel)/,
	     /(BUG: unable to handle kernel) NULL pointer dereference/,
	     /(BUG: unable to handle kernel) paging request/
		line = $1
		bug_to_bisect = $1
	when /(BUG: scheduling while atomic:)/,
	     /(BUG: Bad page map in process)/,
	     /(BUG: Bad page state in process)/,
	     /(BUG: soft lockup - CPU#\d+ stuck for \d+s!)/,
	     /(BUG: spinlock .* on CPU#\d+)/
		line = $1
		bug_to_bisect = $1
	when /(BUG: ).* (still has locks held)/,
	     /(INFO: task ).* (blocked for more than \d+ seconds)/
		line = $1 + $2
		bug_to_bisect = $2
	when /WARNING:.* at .* ([a-zA-Z.0-9_]+\+0x)/
		bug_to_bisect = 'WARNING:.* at .* ' + $1.sub(/\.(isra|constprop|part)\.[0-9]+\+0x/, '')
		line =~ /(at .*)/
		line = "WARNING: " + $1
	when /(Kernel panic - not syncing: No working init found.)  Try passing init= option to kernel. /,
	     /(Kernel panic - not syncing: No init found.)  Try passing init= option to kernel. /
		line = $1
		bug_to_bisect = line
	when /(Out of memory: Kill process) \d+ \(/
		line = $1
		bug_to_bisect = $1
        # old format: "[  122.209638 ] ??? Writer stall state 8 g62150 c62149 f0x2"
        # new format: "[  122.209638 ] ??? Writer stall state RTWS_STUTTER(8) g62150 c62149 f0x2"
	when /(Writer stall state \w*).+ g\d+ c\d+ f/
		line = $1
		bug_to_bisect = $1
	when /(rcu_sched kthread starved) for \d+ jiffies/
		line = $1
		bug_to_bisect = $1
	when /(Could not create tracefs)/
		line = $1
		bug_to_bisect = $1
	when /(used greatest stack depth:)/
		line = $1
		bug_to_bisect = $1
	# printk(KERN_ERR "BUG: Dentry %p{i=%lx,n=%pd} still in use (%d) [unmount of %s %s]\n"
	when  /(BUG: Dentry ).* (still in use) .* \[unmount of /
		line = $1 + $2
		bug_to_bisect = $1 + '.* ' + $2
	when /([A-Z]+[ a-zA-Z]*): [a-f0-9]{4} \[#[0-9]+\] /
		line = $1
		bug_to_bisect = $1
	when /(BUG: KASan: [a-z ]+) in /
		line = $1
		bug_to_bisect = $1
	when /^backtrace:([a-zA-Z0-9_]+)/,
	     /^calltrace:([a-zA-Z0-9_]+)/
		bug_to_bisect = $1 + '+0x'
	when /Corrupted low memory at/
		# [   61.268659] Corrupted low memory at ffff880000007b08 (7b08 phys) = 27200c000000000
		bug_to_bisect = oops_to_bisect_pattern line
		line = line.sub(/\b[0-9a-f]+\b phys/, "# phys").sub(/= \b[0-9a-f]+\b/, "= #")
	else
		bug_to_bisect = oops_to_bisect_pattern line
	end

	error_id = line

	error_id.gsub! /\ \]$/, ""					# [ INFO: possible recursive locking detected ]
	error_id.gsub! /\/c\/kernel-tests\/src\/[^\/]+\//, ''
	error_id.gsub! /\/c\/(wfg|yliu)\/[^\/]+\//, ''
	error_id.gsub! /\/lkp\/[^\/]+\/linux[0-9]*\//, ''
	error_id.gsub! /\/kernel-tests\/linux[0-9]*\//, ''
	error_id.gsub! /\.(isra|constprop|part)\.[0-9]+/, ''

	# [   31.694592] ADFS-fs error (device nbd10): adfs_fill_super: unable to read superblock
	# [   33.147854] block nbd15: Attempted send on closed socket
	# /c/linux-next% git grep -w 'register_blkdev' | grep -o '".*"'
	error_id.gsub! /\b(bcache|blkext|btt|dasd|drbd|fd|hd|jsfd|lloop|loop|md|mdp|mmc|nbd|nd_blk|nfhd|nullb|nvme|pmem|ramdisk|scm|sd|simdisk|sr|ubd|ubiblock|virtblk|xsysace|zram)\d+/, '\1#'

	error_id.gsub! LINUX_DEVICE_NAMES_RE, '\1#'

	error_id.gsub! /\b[0-9a-f]{8}\b/, "#"
	error_id.gsub! /\b[0-9a-f]{16}\b/, "#"
	error_id.gsub! /(=)[0-9a-f]+\b/, '\1#'
	error_id.gsub! /[+\/]0x[0-9a-f]+\b/, ''
	error_id.gsub! /[+\/][0-9a-f]+\b/, ''

	error_id = common_error_id(error_id)

	error_id.gsub! /([a-z]:)[0-9]+\b/, '\1'				# WARNING: at arch/x86/kernel/cpu/perf_event.c:1077 x86_pmu_start+0xaa/0x110()
	error_id.gsub! /#:\[<#>\]\[<#>\]/, ''				# RIP: 0010:[<ffffffff91906d8d>]  [<ffffffff91906d8d>] validate_chain+0xed/0xe80

	[error_id, bug_to_bisect]
end
