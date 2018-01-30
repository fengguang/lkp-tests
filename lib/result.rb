#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'set'
require "#{LKP_SRC}/lib/lkp_git"
require "#{LKP_SRC}/lib/run-env"

DEFAULT_COMPILER = 'gcc-7'.freeze

RESULT_MNT = "#{result_prefix}/result".freeze
RESULT_PATHS = '/lkp/paths'.freeze

def tbox_group(hostname)
  if hostname =~ /.+-\d+$/
    hostname.sub(/-\d+$/, '').sub(/-\d+-/, '-')
  else
    hostname
  end
end

def is_tbox_group(hostname)
  return nil unless hostname.is_a?(String) && !hostname.empty?
  Dir[LKP_SRC + '/hosts/' + hostname][0]
end

class ResultPath < Hash
  MAXIS_KEYS = %w[tbox_group testcase path_params rootfs kconfig compiler commit].freeze
  AXIS_KEYS = (MAXIS_KEYS + ['run']).freeze

  PATH_SCHEME = {
    'default' => %w[path_params tbox_group rootfs kconfig compiler commit run],
    'health-stats' => %w[path_params run],
    'lkp-bug' => %w[path_params run],
    'hwinfo' => %w[tbox_group run],
    'build-dpdk' => %w[rootfs dpdk_config commit dpdk_compiler dpdk_commit run],
    'dpdk-dts' => %w[rootfs dpdk_config dpdk_compiler dpdk_commit run],
    'build-qemu' => %w[qemu_config qemu_commit run],
    'build-nvml' => %w[nvml_commit run],
    'build-acpica' => %w[acpica_commit test run],
    'build-sof' => %w[sof_config sof_commit soft_commit run],
    'kvm-unit-tests-qemu' => %w[path_params tbox_group rootfs kconfig compiler commit qemu_config qemu_commit run],
    'nvml-unit-tests' => %w[path_params tbox_group rootfs kconfig compiler commit nvml_commit run],
    'mbtest' => %w[path_params tbox_group rootfs kconfig compiler commit mbt_commit run],
    'sof_test' => %w[path_params tbox_group rootfs kconfig compiler commit sof_commit run],
    'kvm-kernel-boot-test' => %w[tbox_group kconfig commit qemu_config qemu_commit linux_commit run]
  }.freeze

  def path_scheme
    PATH_SCHEME[self['testcase']] || PATH_SCHEME['default']
  end

  def parse_result_root(rt)
    dirs = rt.sub(/#{RESULT_MNT}\d*/, '').split('/')
    dirs.shift if dirs[0] == ''

    self['testcase'] = dirs.shift
    ps = path_scheme

    ndirs = dirs.size
    ps.each do |key|
      self[key] = dirs.shift
    end

    if ps.include?('commit')
      unless self['commit'] && sha1_40?(self['commit'])
        # $stderr.puts "ResultPath parse error for #{rt}"
        return false
      end
    end

    # for rt and _rt
    ps.size == ndirs || ps.size == ndirs + 1
  end

  def assemble_result_root(skip_keys = nil)
    dirs = [
      RESULT_MNT,
      self['testcase']
    ]

    path_scheme.each do |key|
      next if skip_keys && skip_keys.include?(key)
      dirs << self[key]
    end

    dirs.join '/'
  end

  def _result_root
    assemble_result_root ['run'].to_set
  end

  def result_root
    assemble_result_root
  end

  def test_desc_keys(dim, dim_not_a_param)
    dim = /^#{dim}$/ if dim.instance_of? String

    keys = ['testcase'] + path_scheme
    keys.delete_if { |key| key =~ dim } if dim_not_a_param

    default_removal_pattern = /compiler|^rootfs$|^kconfig$/
    keys.delete_if { |key| key =~ default_removal_pattern && key !~ dim }

    keys
  end

  def test_desc(dim, dim_not_a_param)
    keys = test_desc_keys(dim, dim_not_a_param)

    keys.map { |key| self[key] }.compact.join '/'
  end

  def parse_test_desc(desc, dim = 'commit', dim_not_a_param = true)
    values = desc.split('/')
    keys = test_desc_keys dim, dim_not_a_param
    kv = {}
    keys.each.with_index do |k, i|
      kv[k] = values[i]
    end
    kv
  end

  def params_file
    [
      RESULT_MNT,
      self['testcase'],
      'params.yaml'
    ].join '/'
  end

  def each_commit
    return enum_for(__method__) unless block_given?

    path_scheme.each do |axis|
      case axis
      when 'commit'
        yield 'linux', axis
      when /_commit$/
        yield axis.sub(/_commit$/, ''), axis
      end
    end
  end

  class << self
    def maxis_keys(test_case)
      PATH_SCHEME[test_case].reject { |key| key == 'run' }
    end

    #
    # code snippet from MResultRootCollection
    # FIXME rli9 refactor MResultRootCollection to embrace different maxis keys
    #
    def grep(test_case, options = {})
      pattern = [RESULT_MNT, test_case, PATH_SCHEME[test_case].map { |key| options[key] || '.*' }].flatten.join('/')

      cmdline = "grep -he '#{pattern}' /lkp/paths/????-??-??-* | sed -e 's#[0-9]\\+/$##' | sort | uniq"
      `#{cmdline}`
    end
  end
end

class << ResultPath
  def parse(rt)
    rp = new
    rp.parse_result_root(rt)
    rp
  end

  def new_from_axes(axes)
    rp = new
    rp.update(axes)
    rp
  end
end
