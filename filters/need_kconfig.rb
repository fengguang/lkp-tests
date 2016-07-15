#!/usr/bin/env ruby

def read_kconfig_lines
	return nil unless self['kernel']
	kconfig_file = File.expand_path '../.config', kernel
	kconfig_lines = File.read kconfig_file
end

def check_kconfig(kconfig_lines, line)
	case line
	when /^(CONFIG_[A-Z0-9_])+=n/
		name = $1
		kconfig_lines.index("# #{name} is not set") or
		kconfig_lines !~ /^#{name}=[ym]/
	when /^(CONFIG_[A-Z0-9_]+=[ym])/, /^(CONFIG_[A-Z0-9_]+)/
		kconfig_lines =~ /^#{$1}/
	else
		$stderr.puts "unknown kconfig option: #{line}"
		true
	end
end

def check_all(kconfig_lines)
	Array(___).each do |e|
		unless check_kconfig(kconfig_lines, e)
			raise Job::ParamError, "kconfig not satisfied: #{e}"
		end
	end
end

if kconfig_lines = read_kconfig_lines
	check_all(kconfig_lines)
end
