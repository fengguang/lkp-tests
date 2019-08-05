#!/usr/bin/env ruby

require 'yaml'

def read_kernel_version_from_context
  return nil unless self['kernel']

  context_file = File.expand_path '../context.yaml', kernel
  return nil unless File.exist? context_file

  context = YAML.load(File.read(context_file))
  context['rc_tag']
end

def read_kconfig_lines
  return nil unless self['kernel']

  kconfig_file = File.expand_path '../.config', kernel
  return nil unless File.exist? kconfig_file

  File.read kconfig_file
end

def check_kconfig(kconfig_lines, line)
  case line
  when /^(CONFIG_[A-Z0-9_]+)=n/
    name = $1
    kconfig_lines.index("# #{name} is not set") ||
      kconfig_lines !~ /^#{name}=[ym]/
  when /^(CONFIG_[A-Z0-9_]+=[ym])/, /^(CONFIG_[A-Z0-9_]+)/, /^(CONFIG_[A-Z0-9_]+=[0-9]+)/
    kconfig_lines =~ /^#{$1}/
  else
    warn "unknown kconfig option: #{line}"
    true
  end
end

def check_all(kconfig_lines)
  kernel_version = read_kernel_version_from_context
  $___.each do |e|
    # we use regular expression to redesign include kconfig format, like this:
    # CONFIG_XXXX=m ~ v(4\.0) # support kernel >=v4.0-rc1 && <=v4.0
    # CONFIG_YYYY=y ~ v(4\.1[7-9]|4\.20|5\.) # support kernel >=v4.17-rc1
    # CONFIG_ZZZZ=y ~ v(4\.|5\.0) # support kernel >=v4.0-rc1 && <=v5.0
    # note: just match kernel version from v4.0 to lastest
    config, kernel_version_regexp = e.split(' ~ ')
    if kernel_version && kernel_version_regexp
      next if kernel_version !~ /#{kernel_version_regexp}/
    end
    next if check_kconfig(kconfig_lines, config)

    # need_kconfig
    kconfig_error_message = "#{File.basename __FILE__}: #{config} has not been compiled"
    kconfig_error_message = "#{kconfig_error_message} by this kernel (#{kernel_version} based)" if kernel_version
    kconfig_error_message = "#{kconfig_error_message}, it is supported by kernel matching #{kernel_version_regexp} regexp" if kernel_version_regexp
    raise Job::ParamError, kconfig_error_message.to_s unless __FILE__ =~ /suggest_kconfig/

    puts "suggest kconfig: #{config}"
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

kconfig_lines = read_kconfig_lines
check_all(kconfig_lines) if kconfig_lines
