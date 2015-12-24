LKP_SRC ||= ENV['LKP_SRC']

require "time"

require "#{LKP_SRC}/lib/common.rb"
require "#{LKP_SRC}/lib/property.rb"
require "#{LKP_SRC}/lib/yaml.rb"
require "#{LKP_SRC}/lib/result.rb"
require "#{LKP_SRC}/lib/nresult_root.rb"

def rt_create_time_from_job(job)
	end_time = job['end_time']
	if end_time
		Time.at(end_time.to_i)
	else
		job['dequeue_time']
	end
end

class ResultRoot < CResultRoot
	JOB_FILE = 'job.yaml'

	include Property
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
		@date_glob = nil
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

		date_glob = @date_glob || DATE_GLOB
		files = Dir[File.join INDEX_DIR, date_glob + '-*']
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
		@_rt = MResultRoot.new fields[4]
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

	def eql?(_rto)
		@axes.eql?(_rto.axes)
	end

	def hash
		@axes.hash
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

	def result_roots
		result_root_paths.map { |p|
			ResultRoot.new p
		}
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

	def from_nmresult_root(nmresult_root)
		new nmresult_root.mresult_root_path
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

		cmdline = "grep -he '#{pattern}' /lkp/paths/????-??-??-*"
		@other_conditions.values.each { |ocond|
			cmdline += " | grep -e '#{ocond}'"
		}
		cmdline += " | sed -e 's#[0-9]\\+/$##' | sort | uniq"
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

def convert_one_mresult_root(_rt)
	mrtts = mrt_table_set
	n = mrtts.new_node(_rt.axes)
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

def create_mresult_root_tables
	MResultRootTableSet.create_tables_layout(true)
end

def convert_all_mresult_root(date_from_in = nil, date_to_in = nil)
	rtc = ResultRootCollection.new
	date = date_of_time date_from_in
	date_to = date_of_time date_to_in
	n = 0
	while date <= date_to
		rtc.set_date(date)
		rtc.each { |rt|
			n+=1
			_rt = rt._result_root
			convert_one_mresult_root(_rt) and puts "#{n}: #{_rt}"
		}
		date += ONE_DAY
	end
end

def convert_mrt(_rt_path)
	_rt = MResultRoot.new(_rt_path)
	convert_one_mresult_root(_rt)
end

def delete_mrt(_rt_path)
	mrtts = mrt_table_set
	_rt = MResultRoot.new(_rt_path)
	n = mrtts.open_node(_rt.axes)
	if File.exist? n.path
		n.delete
	end
end
