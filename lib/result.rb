#!/usr/bin/ruby

RESULT_MNT	= '/result'
RESULT_PATHS	= '/lkp/paths'
RESULT_ROOT_DEPTH = 8

def tbox_group(hostname)
	hostname.sub /-[0-9]+$/, ''
end

class ResultPath < Hash

	def parse_result_root(rt)
		dirs = rt.sub(RESULT_MNT, '').split('/')
		dirs.shift if dirs[0] == ''

		self['testbox'],
		self['testcase'],
		self['path_params'],
		self['rootfs'],
		self['kconfig'],
		self['commit'],
		self['run'] = dirs
	end

	def _result_root
		[
			RESULT_MNT,
			tbox_group(self['testbox']),
			self['testcase'],
			self['path_params'],
			self['rootfs'],
			self['kconfig'],
			self['commit']
		].join '/'
	end

	def result_root
		[
			RESULT_MNT,
			tbox_group(self['testbox']),
			self['testcase'],
			self['path_params'],
			self['rootfs'],
			self['kconfig'],
			self['commit'],
			self['run']
		].join '/'
	end

	def test_desc(dim, dim_not_a_param)
		self.delete(dim) if dim_not_a_param
		self.delete('rootfs') if dim != 'rootfs'
		self.delete('kconfig') if dim != 'kconfig'
		[
			self['testbox'],
			self['testcase'],
			self['path_params'],
			self['rootfs'],
			self['kconfig'],
			self['commit']
		].compact.join '/'
	end

	def params_file
		[
			RESULT_MNT,
			tbox_group(self['testbox']),
			self['testcase'],
			'params.yaml'
		].join '/'
	end
end
