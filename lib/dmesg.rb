#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']

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
				if @large_dmesg_timestamps.empty? || @large_dmesg_timestamps.any? {|large_dmesg_timestamp| large_dmesg_timestamp <= dmesg_timestamp}
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

def grep_crash_head(dmesg_file, grep_options = '')
	oops = %x[ xzgrep -a -f #{LKP_SRC}/etc/oops-pattern #{grep_options} #{dmesg_file} | grep -v -f #{LKP_SRC}/etc/oops-pattern-ignore |
		   awk '{line = $0; sub(/^(<[0-9]>)?\[[ 0-9.]+\] /, "", line); if (!x[line]++) print;}'
	]
	unless oops.empty?
		oops += `xzgrep -v -F ' ? ' #{dmesg_file} |
			 grep -E -B1 '(do_one_initcall|kthread|kernel_thread|process_one_work|SyS_[a-z0-9_]+|init_[a-z0-9_]+|[a-z0-9_]+_init)\\+0x' |
			 grep -v -E  '(do_one_initcall|kthread|kernel_thread|process_one_work|worker_thread|kernel_init|rest_init|warn_slowpath_)\\+0x' |
			 grep -o -E '[a-zA-Z0-9_.]+\\+0x[0-9a-fx/]+' |
			 awk '!x[$0]++' |
			 sed 's/^/backtrace:&/' `
	end

	oops
end

def grep_printk_errors(kmsg_file, dmesg_file, dmesg_lines)
	return '' if ENV['RESULT_ROOT'].index '/trinity/'
	return '' unless File.exist?('/lkp/printk-error-messages')

	if kmsg_file == dmesg_file
		dmesg = dmesg_lines.join "\n"
	elsif File.exist?(kmsg_file)
		dmesg = File.read kmsg_file
	else
		dmesg = dmesg_lines.join "\n"
		kmsg_file = dmesg_file
	end

	oops = `grep -a -v -f #{LKP_SRC}/etc/oops-pattern #{kmsg_file} | grep -a -F -f /lkp/printk-error-messages`
	oops += `grep -a '^<[0123]>' #{kmsg_file} |
		 grep -a -v -f #{LKP_SRC}/etc/oops-pattern |
		 grep -a -v -F -f /lkp/printk-error-messages -f #{LKP_SRC}/etc/kmsg-blacklist` if kmsg_file =~ /\/kmsg$/
	oops += `grep -a -f #{LKP_SRC}/etc/ext4-crit-pattern	#{kmsg_file}` if dmesg.index 'EXT4-fs ('
	oops += `grep -a -f #{LKP_SRC}/etc/xfs-alert-pattern	#{kmsg_file}` if dmesg.index 'XFS ('
	oops += `grep -a -f #{LKP_SRC}/etc/btrfs-crit-pattern	#{kmsg_file}` if dmesg.index 'btrfs: '
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
