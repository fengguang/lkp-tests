LKP_SRC ||= ENV['LKP_SRC']

require "time"

require "#{LKP_SRC}/lib/common.rb"
require "#{LKP_SRC}/lib/property.rb"
require "#{LKP_SRC}/lib/yaml.rb"
require "#{LKP_SRC}/lib/result.rb"
require "#{LKP_SRC}/lib/stats.rb"
require "#{LKP_SRC}/lib/job.rb"
require "#{LKP_SRC}/lib/data_store.rb"

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
		end_time = j['end_time']
		if end_time
			create_time = Time.at(end_time.to_i)
		else
			create_time = j['dequeue_time']
		end
		m['create_time'] = create_time
		m
	end

	def desc
		@desc ||= calc_desc
	end

	def _result_root
		rp = ResultPath.parse(@path)
		rp._result_root
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

# Result root for multiple runs of a job
# M here stands for multiple runs
# _rt or mrt may be used as variable name
class MResultRoot
	# TODO: remove .dmesg after we convert all .dmesg to dmesg
	DMESG_FILE_GLOBS = ['dmesg.xz', 'dmesg', '.dmesg', 'kmsg.xz', 'kmsg']
	DMESG_GLOBS = DMESG_FILE_GLOBS.map { |g| "[0-9]*/#{g}" }
	DMESG_JSON_GLOB = '[0-9]*/dmesg.json'
	JOB_GLOB = '[0-9]*/job.yaml'
	JOB_FILE1 = 'job.yaml'
	COMPLETIONS_FILE = 'completions'
	MATRIX = 'matrix.json'

	def initialize(path)
		@path = path
		@path.freeze
		@axes = calc_axes
	end

	include DirObject

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

	def completions
		open(COMPLETIONS_FILE, "r") { |f|
			f.each_line.map { |line|
				Completion.new line
			}.sort_by { |cmp| -cmp.time.to_i }
		}
	rescue Errno::ENOENT
		[]
	end

	ResultPath::MAXIS_KEYS.each { |k|
		define_method(k.intern) { @axes[k] }
	}
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

class ResultRootTable < DataStore::Table
	RESULT_ROOT_DIR = File.join LKP_DATA_DIR, 'result_root'
end

class << ResultRootTable
	def create_layout(force = false)
		return if !force && DataStore::Layout.exists?(self::RESULT_ROOT_DIR)
		FileUtils.rm_rf(self::RESULT_ROOT_DIR)
		layout = DataStore::Layout.create_new self::RESULT_ROOT_DIR
		dmap = DataStore::Map
		rtp = ResultPath.new
		as_keys = ['testcase'] + rtp.path_scheme
		as_keys[as_keys.index 'path_params'] = dmap::ALL_OTHERS_KEY
		layout.add_map(dmap::NAME => 'default',
			       dmap::AXIS_KEYS => as_keys,
			       dmap::SUPPRESS_LAST => true)
		layout.set_compress_matrix true
		layout.save
	end

	def open
		super(self::RESULT_ROOT_DIR)
	end
end

def convert_one_result_root(rt, rt_table)
	n = rt_table.new_node(rt.axes)
	n.create_storage_link(rt.path)
	n.update_desc { |desc|
		desc.update(rt.desc)
	}
	n.index(true)
end

def convert_all_result_root
	ResultRootTable.create_layout(true)
	rtt = ResultRootTable.open

	rtc = ResultRootCollection.new
	rtc.each.first(3).each { |rt|
		puts rt
		convert_one_result_root(rt, rtt)
	}
end

def convert_rt(rt_path)
	rtt = ResultRootTable.open
	rt = ResultRoot.new(rt_path)
	convert_one_result_root(rt, rtt)
end

def delete_rt(rt_path)
	rtt = ResultRootTable.open
	rt = ResultRoot.new(rt_path)
	n = rtt.open_node(rt.axes)
	rtt.delete(n)
end
