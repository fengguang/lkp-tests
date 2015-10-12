LKP_SRC ||= ENV['LKP_SRC']

require "#{LKP_SRC}/lib/common.rb"
require "#{LKP_SRC}/lib/property.rb"
require "#{LKP_SRC}/lib/yaml.rb"
require "#{LKP_SRC}/lib/stats.rb"
require "#{LKP_SRC}/lib/job.rb"
require "#{LKP_SRC}/lib/result.rb"
require "#{LKP_SRC}/lib/data_store.rb"

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
