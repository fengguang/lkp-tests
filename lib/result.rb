#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']

require 'set'
require "#{LKP_SRC}/lib/lkp_git"

DEFAULT_COMPILER = 'gcc-4.9'

RESULT_MNT	= '/result'
RESULT_PATHS	= '/lkp/paths'

def tbox_group(hostname)
	hostname.sub /-[0-9]+$/, ''
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
		'hwinfo'	=> %w[ tbox_group run ],
		'build-dpdk'	=> %w[ dpdk_config dpdk_compiler dpdk_commit run ],
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
			unless self['commit'] && is_sha1_40(self['commit'])
				#STDERR.puts "ResultPath parse error for #{rt}"
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
		return unless block_given?

		self.each do |axis, val|
			case axis
			when 'commit'
				yield 'linux', axis
			when /_commit$/
				yield axis.sub(/_.*$/, ''), axis
			end
		end
	end

	#
	# return commit axis name, assume single commit axis of result root
	#
	def commit_axis
		#self.keys.find {|axis| axis =~ /commit$/}
		# FIXME rli9 hack code now to check whether it is dpdk, b/c
		# sometimes keys will include 'commit' after loading job file
		# such as MResultRoot.axes_path
		self.keys.include?('dpdk_commit') ? 'dpdk_commit' : self.keys.find {|axis| axis =~ /commit$/}
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
