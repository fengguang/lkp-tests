#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']

require 'set'
require "#{LKP_SRC}/lib/lkp_git"

DEFAULT_COMPILER = 'gcc-4.9'

RESULT_MNT	= '/result'
RESULT_PATHS	= '/lkp/paths'

def tbox_group(hostname)
	hostname.sub(/-[0-9]+$/, '').sub(/-[\d]+-/, '-')
end

def is_tbox_group(hostname)
	return nil unless String === hostname and not hostname.empty?
	Dir[LKP_SRC + '/hosts/' + hostname][0]
end

class ResultPath < Hash
	MAXIS_KEYS = ['tbox_group', 'testcase', 'path_params', 'rootfs', 'kconfig', 'compiler', 'commit'].freeze
	AXIS_KEYS = (MAXIS_KEYS + ['run']).freeze

	PATH_SCHEME = {
		'legacy'	=> %w[ testcase path_params rootfs kconfig commit run ],
		'default'	=> %w[ path_params tbox_group rootfs kconfig compiler commit run ],
		'health-stats'	=> %w[ path_params run ],
		'lkp-bug'	=> %w[ path_params run ],
		'hwinfo'	=> %w[ tbox_group run ],
		'build-dpdk'	=> %w[ dpdk_config commit dpdk_compiler dpdk_commit run ],
		# FIXME rli9 result path can be part of test configuration, like combine # - indicated parameter in test
		# FIXME rli9 move to lkp-core for internal project
		'android-kpi' => %w[ android_kpi android_manifest android_lunch android_commit run ],
		'build-android'	=> %w[ android_manifest android_lunch android_commit run ],
	}

	def path_scheme
		PATH_SCHEME[self['testcase']] || PATH_SCHEME['default']
	end

	def parse_result_root(rt)
		dirs = rt.sub(RESULT_MNT, '').split('/')
		dirs.shift if dirs[0] == ''

		self['testcase'] = dirs.shift
		ps = path_scheme()

		# for backwards compatibilty
		if is_tbox_group(self['testcase']) and not is_tbox_group(dirs[1])
			self['tbox_group'] = self['testcase']
			ps = PATH_SCHEME['legacy']
		end

		ndirs = dirs.size
		ps.each do |key|
			self[key] = dirs.shift
		end

		if ps.include?('commit')
			unless self['commit'] && Git.sha1_40?(self['commit'])
				#$stderr.puts "ResultPath parse error for #{rt}"
				return false
			end
		end

		# for rt and _rt
		return ps.size == ndirs || ps.size == ndirs + 1
	end

	def assemble_result_root(skip_keys = nil)
		dirs = [
			RESULT_MNT,
			self['testcase']
		]

		path_scheme.each do |key|
			next if skip_keys and skip_keys.include? key
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
		keys = [
			'testcase',
			'path_params',
			'tbox_group',
			'rootfs',
			'kconfig',
			'commit'
		]
		keys.delete(dim) if dim && dim_not_a_param
		keys.delete('rootfs') if dim != 'rootfs'
		keys.delete('kconfig') if dim != 'kconfig'
		keys
	end

	def test_desc(dim, dim_not_a_param)
		self.delete(dim) if dim_not_a_param
		self.delete('rootfs') if dim != 'rootfs'
		self.delete('kconfig') if dim != 'kconfig'
		[
			self['testcase'],
			self['path_params'],
			self['tbox_group'],
			self['rootfs'],
			self['kconfig'],
			self['commit']
		].compact.join '/'
	end

	def parse_test_desc(desc, dim='commit', dim_not_a_param=true)
		values = desc.split('/')
		keys = test_desc_keys dim, dim_not_a_param
		kv = {}
		keys.each.with_index { |k, i|
			kv[k] = values[i]
		}
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

		self.each do |axis, val|
			case axis
			when 'commit'
				yield 'linux', axis
			when /_commit$/
				yield axis.sub(/_commit$/, ''), axis
			end
		end
	end

	#
	# return commit axis name, assume single commit axis of result root
	#
	def commit_axis
		self.path_scheme.find {|axis| axis =~ /commit$/}
	end

	class << self
		def maxis_keys(test_case)
			PATH_SCHEME[test_case].reject {|key| key == 'run'}
		end

		#
		# code snippet from MResultRootCollection
		# FIXME rli9 refactor MResultRootCollection to embrace different maxis keys
		#
		def grep(test_case, options = {})
			pattern = [RESULT_MNT, test_case, PATH_SCHEME[test_case].map {|key| options[key] || '.*'}].flatten.join('/')

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
