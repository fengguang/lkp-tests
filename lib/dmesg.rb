#!/usr/bin/ruby

def fixup_dmesg(line)
	line.chomp!

	# remove absolute path names
	line.sub!(%r{/lkp/[^/]+/linux[0-9]*/}, '')
	line.sub!(%r{/c/kernel-tests/src/[^/]+/}, '')
	line.sub!(%r{/kbuild/src/[^/]+/}, '')
	line.sub!(%r{/c/(wfg|yliu)/[^/]+/}, '')

	line.sub!(/\.(isra|constprop|part)\.[0-9]+\+0x/, '+0x')

	# break up mixed messages
	case line
	when /^<[0-9]>/
	when /(.+)(\[ *[0-9]{1,6}\.[0-9]{6}\] .*)/
		line = $1 + "\n" + $2
	end

	return line
end

def grep_crash_head(dmesg, grep_options = '')
	oops = %x[ grep -a -f #{LKP_SRC}/etc/oops-pattern #{grep_options} #{dmesg} |
		   grep -v -e 'INFO: NMI handler .* took too long to run' |
		   awk '{line = $0; sub(/^(<[0-9]>)?\[[ 0-9.]+\] /, "", line); if (!x[line]++) print;}'
	]
	unless oops.empty?
		oops += `grep -v -F ' ? ' #{dmesg} |
			 grep -E -B1 '(do_one_initcall|kthread|kernel_thread|process_one_work|SyS_[a-z0-9_]+|init_[a-z0-9_]+|[a-z0-9_]+_init)\\+0x' |
			 grep -v -E  '(do_one_initcall|kthread|kernel_thread|process_one_work|worker_thread|kernel_init|rest_init|warn_slowpath_)\\+0x' |
			 grep -o -E '[a-zA-Z0-9_.]+\\+0x[0-9a-fx/]+' |
			 awk '!x[$0]++' |
			 sed 's/^/backtrace:&/' `
		return oops
	end

	if system "grep -q -F 'EXT4-fs ('	#{dmesg}"
		oops = `grep -a -f #{LKP_SRC}/etc/ext4-crit-pattern	#{grep_options} #{dmesg}`
		return oops unless oops.empty?
	end

	if system "grep -q -F 'XFS ('	#{dmesg}"
		oops = `grep -a -f #{LKP_SRC}/etc/xfs-alert-pattern	#{grep_options} #{dmesg}`
		return oops unless oops.empty?
	end

	if system "grep -q -F 'btrfs: '	#{dmesg}"
		oops = `grep -a -f #{LKP_SRC}/etc/btrfs-crit-pattern	#{grep_options} #{dmesg}`
		return oops unless oops.empty?
	end

	return ''
end

