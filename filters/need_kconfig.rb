#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'yaml'
require "#{LKP_SRC}/lib/kernel_tag"

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

def kernel_include_kconfig?(kernel_version, config_info)
  kernel_version = KernelTag.new(kernel_version)

  config_info.split(' && ').each do |constraint|
    match = constraint.match(/(?<operator><|>|==|!=|<=|>=) (?<kernel_tag>v[0-9]\.\d+(-rc\d+)*)/)
    if match.nil? || match[:operator].nil? || match[:kernel_tag].nil?
      raise Job::ParamError, "Wrong syntax of kconfig setting: #{config_info}"
    else
      return false unless kernel_version.method(match[:operator]).(KernelTag.new(match[:kernel_tag]))
    end
  end
  true
end

def check_all(kconfig_lines)
  uncompiled_kconfigs_info = []

  kernel_version = read_kernel_version_from_context

  $___.each do |e|
    # we use regular expression to redesign include kconfig format, like this:
    # CONFIG_XXXX=m: '>= v4.0-rc1 && <= v4.0'
    # CONFIG_YYYY=y: '>= v4.17-rc1'
    # note: just match kernel version from v4.0 to lastest
    config, config_info = e.split(' ~ ')
    if kernel_version && config_info
      next unless kernel_include_kconfig?(kernel_version, config_info)
    end

    next if check_kconfig(kconfig_lines, config)

    kconfig_info = config
    kconfig_info += " supported by kernel #{config_info.gsub('\'','')}" if config_info
    uncompiled_kconfigs_info.push kconfig_info
  end

  return nil if uncompiled_kconfigs_info.empty?

  kconfigs_error_message = "#{File.basename __FILE__}: #{uncompiled_kconfigs_info.uniq} has not been compiled"
  kconfigs_error_message += " by this kernel (#{kernel_version} based)" if kernel_version
  raise Job::ParamError, kconfigs_error_message.to_s unless __FILE__ =~ /suggest_kconfig/

  puts "suggest kconfigs: #{uncompiled_kconfigs_info.uniq}"
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
