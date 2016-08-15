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
	when /^(CONFIG_[A-Z0-9_]+=[ym])/, /^(CONFIG_[A-Z0-9_]+)/, /^(CONFIG_[A-Z0-9_]+=[0-9]+)/
		kconfig_lines =~ /^#{$1}/
	else
		$stderr.puts "unknown kconfig option: #{line}"
		true
	end
end

def check_all(kconfig_lines)
	$___.each do |e|
		unless check_kconfig(kconfig_lines, e)
			if __FILE__ =~ /suggest_kconfig/
				puts "suggest kconfig: #{e}"
			else # need_kconfig
				raise Job::ParamError, "kconfig not satisfied: #{e}"
			end
		end
	end
end

def check_arch_constraints
	model = self['model']
	rootfs = self['rootfs']
	kconfig = self['kconfig']

	case model
	when /^qemu-system-x86_64/
		case rootfs
		when /-x86_64/
			# Check kconfig to find mismatches earlier, in cases
			# when the exact kernel is still not available:
			# - commit=BASE|HEAD|CYCLIC_BASE|CYCLIC_HEAD late binding
			# - know exact commit, however yet to compile the kernel
			raise Job::ParamError, "32bit kernel cannot run 64bit rootfs: '#{kconfig}' '#{rootfs}'" if kconfig =~ /^i386-/
			$___ << 'CONFIG_X86_64=y'
		when /-i386/
			$___ << 'CONFIG_IA32_EMULATION=y' if kconfig =~ /^x86_64-/
		end
	when /^qemu-system-i386/
		case rootfs
		when /-x86_64/
			raise Job::ParamError, "32bit QEMU cannot run 64bit rootfs: '#{model}' '#{rootfs}'"
		when /-i386/
			raise Job::ParamError, "32bit QEMU cannot run 64bit kernel: '#{model}' '#{kconfig}'" if kconfig =~ /^x86_64-/
			$___ << 'CONFIG_X86_32=y'
		end
	end
end

$___ = Array(___)

check_arch_constraints

if kconfig_lines = read_kconfig_lines
	check_all(kconfig_lines)
end
