LKP_SRC ||= ENV['LKP_SRC']

require "time"

require "#{LKP_SRC}/lib/common.rb"
require "#{LKP_SRC}/lib/property.rb"
require "#{LKP_SRC}/lib/yaml.rb"
require "#{LKP_SRC}/lib/result.rb"
require "#{LKP_SRC}/lib/stats.rb"
require "#{LKP_SRC}/lib/job.rb"
require "#{LKP_SRC}/lib/data_store.rb"

def rt_create_time_from_job(job)
	job['end_time'] && job['dequeue_time']
end

class ResultRoot
	JOB_FILE = 'job.yaml'

	include DirObject
	prop_reader :axes

	private

	def initialize(path)
		@path = path
		@path.freeze
		@axes = calc_axes
	end

	def calc_axes
		as = job.axes
		rp = ResultPath.parse(@path)
		as['run'] = rp['run']
		as
	end

	public

	def axes_path
		as = deepcopy(@axes)
		as['path_params'] = job.path_params
		as
	end

	def job
		@job ||= Job.open path(JOB_FILE)
	end

	def calc_desc
		m = {}
		j = job
		['queue', 'job_state'].each { |k|
			m[k] = j[k]
		}
		m['create_time'] = rt_create_time_from_job j
		m
	end

	def desc
		@desc ||= calc_desc
	end

	def _result_root_path
		rp = ResultPath.parse(@path)
		rp._result_root
	end

	def _result_root
		MResultRoot.new _result_root_path
	end

	def collection
		ResultRootCollection.new axes_path
	end
end

# Minimal implementation just for convert to general data store
class ResultRootCollection
	INDEX_DIR = '/lkp/paths'

	include Enumerable

	def initialize(conditions = {})
		@conditions = conditions
	end

	def set(key, value)
		@conditions[key] = value
		self
	end

	def unset(key)
		@conditions.delete key
		self
	end

	def set_date_glob(glob)
		@date_glob = glob
	end

	def set_date(time)
		@date_glob = str_date(time)
	end

	def set_queue(queue)
		@queue = queue
	end

	def each
		block_given? or return enum_for(__method__)

		files = Dir[File.join INDEX_DIR, DATE_GLOB + '-*']
		files.sort!
		files.reverse!
		files.each { |fn|
			File.open(fn) { |f|
				f.readlines.reverse!.each { |rtp|
				#f.readlines.each { |rtp|
					rtp = rtp.strip
					next if ! File.exists? rtp
					yield ResultRoot.new rtp
				}
			}
		}
	end
end

class Completion
	def initialize(line)
		fields = line.split
		@time = Time.parse(fields[0..2].join ' ')
		@_rt = ResultRoot_.new fields[3]
		@status = fields.drop(4).join ' '
	end

	attr_reader :time, :status

	def to_s
		"#{@time} #{@_rt} #{@status}"
	end
end

# Common Multiple Result Root
#   to share code betwen original MResultRoot and NMResultRoot
module CMResultRoot
	# TODO: remove .dmesg after we convert all .dmesg to dmesg
	DMESG_FILE_GLOBS = ['dmesg.xz', 'dmesg', '.dmesg', 'kmsg.xz', 'kmsg']
	DMESG_GLOBS = DMESG_FILE_GLOBS.map { |g| "[0-9]*/#{g}" }
	DMESG_JSON_GLOB = '[0-9]*/dmesg.json'
	JOB_GLOB = '[0-9]*/job.yaml'
	JOB_FILE1 = 'job.yaml'

	def dmesgs
		DMESG_GLOBS.each { |g|
			dmesgs = glob(g)
			return dmesgs unless dmesgs.empty?
		}
		[]
	end

	def dmesg_jsons
		glob DMESG_JSON_GLOB
	end

	def job_file
		job1 = path(JOB_FILE1)
		return job1 if File.exist? job1
		jobs = glob(JOB_GLOB)
		jobs[0] if jobs.size != 0
	end

	def job
		Job.open job_file
	end

	def complete_matrix(m = nil)
		m ||= matrix
		if m['last_state.is_incomplete_run']
			m = deepcopy(m)
			filter_incomplete_run m
			m
		else
			m
		end
	end

	def runs(m = nil)
		m ||= matrix
		return 0, 0 unless m
		all_runs = matrix_cols m
		cm = complete_matrix m
		complete_runs = matrix_cols cm
		[all_runs, complete_runs]
	end

	ResultPath::MAXIS_KEYS.each { |k|
		define_method(k.intern) { @axes[k] }
	}
end

# Result root for multiple runs of a job
# M here stands for multiple runs
# _rt or mrt may be used as variable name
class MResultRoot
	COMPLETIONS_FILE = 'completions'
	MATRIX = 'matrix.json'

	def initialize(path)
		@path = path
		@path.freeze
		@axes = calc_axes
	end

	include DirObject
	include CMResultRoot

	attr_reader :axes

	def to_s
		@path
	end

	def calc_axes
		if job_file
			job.axes
		else
			rp = ResultPath.parse @path
			Hash[rp.to_a]
		end
	end

	def axes_path
		as = deepcopy(@axes)
		if job_file
			path_params = job.path_params
		else
			rp = ResultPath.parse @path
			path_params = rp['path_params']
		end
		as['path_params'] = path_params
		as
	end

	def goto_commit(commit)
		rp = ResultPath.new
		rp.update(axes_path)
		rp[rp.commit_axis] = commit
		_rtp = rp._result_root
		MResultRoot.new _rtp if File.exists? _rtp
	end

	def collection
		MResultRootCollection.new axes_path
	end

	def boot_collection
		bc = collection.unselect('path_params', 'rootfs')
		bc.testcase = 'boot'
		bc
	end

	def matrix_file
		path(MATRIX)
	end

	def matrix
		try_load_json matrix_file
	end

	def completions
		open(COMPLETIONS_FILE, "r") { |f|
			f.each_line.map { |line|
				Completion.new line
			}.sort_by { |cmp| -cmp.time.to_i }
		}
	rescue Errno::ENOENT
		[]
	end

	def calc_create_time
		(job_file && rt_create_time_from_job(job)) ||
			glob("*").map { |f| File.mtime f }.min
	end

	def calc_desc
		{
			DataStore::CREATE_TIME => calc_create_time
		}
	end

	def desc
		@desc ||= calc_desc
	end
end

class << MResultRoot
	def valid?(path)
		return true if File.exists? File.join(path, self::JOB_FILE1)
		return false if !File.exists? path
		return Dir[File.join path, self::JOB_GLOB].first
	end
end

class MResultRootCollection
	def initialize(conditions = {})
		cond = deepcopy(conditions)
		ResultPath::MAXIS_KEYS.each { |f|
			set_prop f, conditions[f]
			cond.delete f
		}
		@other_conditions = cond
	end

	include Property
	include Enumerable

	prop_with *ResultPath::MAXIS_KEYS

	def pattern
		result_path = ResultPath.new
		ResultPath::MAXIS_KEYS.each { |k|
			result_path[k] = get_prop(k) || '.*'
		}
		result_path._result_root
	end

	def each
		block_given? or return enum_for(__method__)

		cmdline = "grep -he '#{pattern}' /lkp/paths/*"
		@other_conditions.values.each { |ocond|
			cmdline += " | grep -e '#{ocond}'"
		}
		cmdline += " | sed -e '1,$s?\\(.*\\)/[0-9]*?\\1?' | sort | uniq"
		IO.popen(cmdline) { |io|
			io.each_line { |_rtp|
				_rtp = _rtp.strip
				if MResultRoot.valid? _rtp
					yield MResultRoot.new _rtp.strip
				end
			}
			Process.waitpid io.pid
		}
	end

	def select(field, value)
		field = field.to_s
		value = value.to_s
		if ResultPath::MAXIS_KEYS.index field
			set_prop(field, value)
		else
			@other_conditions[field] = value
		end
		self
	end

	def unselect(*fields)
		fields.each { |f|
			f = f.to_s
			if ResultPath::MAXIS_KEYS.index f
				set_prop(f, nil)
			else
				@other_conditions.delete f
			end
		}
		self
	end
end

class MResultRootTable < DataStore::Table
	MRESULT_ROOT_DIR = File.join LKP_DATA_DIR, 'mresult_root'
end

class << MResultRootTable
	def create_layout(force = false)
		return if !force && DataStore::Layout.exist?(self::MRESULT_ROOT_DIR)
		FileUtils.rm_rf(self::MRESULT_ROOT_DIR)
		layout = DataStore::Layout.create_new self::MRESULT_ROOT_DIR
		layout.set_compress_matrix true
		layout.save
		layout.add_index DataStore::DateIndex
		layout.add_index(DataStore::AxisIndex, "commit") { |index|
			index.set_axis_keys ["commit"]
		}
	end

	def open
		super(self::MRESULT_ROOT_DIR)
	end
end

def convert_one_mresult_root(_rt, _rt_table)
	n = _rt_table.new_node(_rt.axes)
	if File.exist? n.path
		false
	else
		n.create_storage_link(_rt.path)
		n.update_desc { |desc|
			desc.update(_rt.desc)
		}
		n.index(true)
		true
	end
end

def convert_all_mresult_root
	MResultRootTable.create_layout(true)
	_rtt = MResultRootTable.open

	exclude_testcases =
		['0day-boot-tests', '0day-kbuild-tests', 'android-kpi', 'gmin-kpi',
		 'health-stats', 'lkp-bug', 'hwinfo',
		 'convert-lkpdoc-to-html', 'convert-lkpdoc-to-html-css',
		 'build-dpdk', 'build-android', 'build-gerrit_change', 'build-gmin',
		 'dpdk-build-test',
		 'ipmi-setup', 'lkp-install-run', 'lkp-services', 'lkp-src', 'pack-deps']

	rtc = ResultRootCollection.new
	n = 0
	rtc.each { |rt|
		n+=1
		break if n > 1000
		_rt = rt._result_root
		next if exclude_testcases.index _rt.testcase
		convert_one_mresult_root(_rt, _rtt) && puts(_rt)
	}
end

def convert_mrt(_rt_path)
	_rtt = ResultRootTable.open
	_rt = ResultRoot.new(_rt_path)
	convert_one_mresult_root(_rt, _rtt)
end

def delete_mrt(_rt_path)
	_rtt = ResultRootTable.open
	_rt = ResultRoot.new(_rt_path)
	n = rtt.open_node(_rt.axes)
	_rtt.delete(n)
end
