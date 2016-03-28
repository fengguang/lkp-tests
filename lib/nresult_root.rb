LKP_SRC ||= ENV['LKP_SRC']

require "#{LKP_SRC}/lib/common.rb"
require "#{LKP_SRC}/lib/property.rb"
require "#{LKP_SRC}/lib/yaml.rb"
require "#{LKP_SRC}/lib/stats.rb"
require "#{LKP_SRC}/lib/job.rb"
require "#{LKP_SRC}/lib/result.rb"
require "#{LKP_SRC}/lib/data_store.rb"

# Common Result Root
# to share code between original ResultRoot and NResultRoot
class CResultRoot
	# TODO: remove .dmesg after we convert all .dmesg to dmesg
	DMESG_FILES = ['dmesg.xz', 'dmesg', '.dmesg', 'kmsg.xz', 'kmsg']
	DMESG_JSON_FILE = 'dmesg.json'
	KMSG_JSON_FILE = 'kmsg.json'
	MATRIX_FILE = 'matrix.json'

	include DirObject

	def initialize(path)
		@path = path
		@path.freeze
	end

	def dmesg_json_file
		fn = path(DMESG_JSON_FILE)
		fn if File.exist?(fn)
	end

	def dmesg_json
		fn = dmesg_json_file
		load_json(fn) if fn
	end

	def kmsg_json_file
		fn = path(KMSG_JSON_FILE)
		fn if File.exist?(fn)
	end

	def kmsg_json
		fn = kmsg_json_file
		load_json(fn) if fn
	end

	def dmesg_file
		DMESG_FILES.each { |fn|
			ffn = path fn
			return ffn if File.exist? ffn
		}
		nil
	end

	def matrix_file
		path(MATRIX_FILE)
	end

	def matrix
		try_load_json matrix_file
	end
end

# Common Multiple Result Root
#   to share code between original MResultRoot and NMResultRoot
module CMResultRoot
	DMESG_GLOBS = CResultRoot::DMESG_FILES.map { |g| "[0-9]*/#{g}" }
	DMESG_JSON_GLOB = '[0-9]*/dmesg.json'
	JOB_GLOB = '[0-9]*/job.yaml'
	JOB_FILE1 = 'job.yaml'
	REPRODUCE_GLOB = '[0-9]*/reproduce.sh'

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

	def reproduce_file
		reproduce_files = glob(REPRODUCE_GLOB)
		reproduce_files[0] unless reproduce_files.empty?
	end

	def result_root_paths
		glob(JOB_GLOB).map { |jfn|
			File.dirname jfn
		}
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

	def result_roots_with_stat(stat)
		result_roots.select { |rt|
			rt.matrix[stat]
		}
	end

	ResultPath::MAXIS_KEYS.each { |k|
		define_method(k.intern) { @axes[k] }
	}
end

class NResultRoot < CResultRoot
end

class NMResultRoot < DataStore::Node
	include CMResultRoot

	def result_roots
		result_root_paths.map { |p|
			NResultRoot.new p
		}
	end

	def collection
		NMResultRootCollection.new axes
	end

	def goto_commit(commit)
		c = collection
		c.set(COMMIT_AXIS_KEY, commit)
		c.to_a.first
	end

	def mresult_root_path
		File.readlink @path
	end

	def to_data
		axes
	end

	class << self
		def from_data(data)
			mrt_table_set.open_node data
		end
	end
end

# Multiple "Multiple Result Root (_rt)"
class MMResultRoot
	def initialize
		@mresult_roots = []
	end

	def add_mresult_root(_rt)
		@mresult_roots << _rt
	end

	def matrix
		merge_matrixes(@mresult_roots.map { |_rt| _rt.matrix })
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

	def axes
		@mresult_roots.first.axes
	end
end

class MResultRootTable < DataStore::Table
	MRESULT_ROOT_DIR = File.join LKP_DATA_DIR, 'mresult_root'

	def initialize(layout)
		super
		@node_class = NMResultRoot
	end
end

class << MResultRootTable
	def table_dir(name)
		File.join self::MRESULT_ROOT_DIR, name
	end

	def create_layout(name, force = false)
		dir = table_dir name
		return if !force && DataStore::Layout.exist?(dir)
		FileUtils.rm_rf(dir)
		layout = DataStore::Layout.create_new dir
		layout.save
		layout.add_index DataStore::DateIndex
		layout
	end

	def open(name)
		super table_dir(name)
	end
end

class LinuxMResultRootTable < MResultRootTable
end

class << LinuxMResultRootTable
	def create_layout(name, force = false)
		layout = super
		layout.add_index(DataStore::AxisIndex, "commit") { |index|
			index.set_axis_keys ["commit"]
		} if layout
		layout
	end
end

class MResultRootTableSet
	LINUX_PERF_TABLE = 'linux_perf'
	LINUX_TABLE = 'linux'
	OTHER_TABLE = 'other'
	LINUX_PERF_TESTCASES =
		['aim7', 'aim9', 'angrybirds', 'autotest', 'blogbench', 'dbench',
		 'dd-write', 'ebizzy', 'fileio', 'fishtank', 'fsmark', 'glbenchmark',
		 'hackbench', 'hpcc', 'idle', 'iozone', 'iperf', 'jsbenchmark', 'kbuild',
		 'ku-latency', 'linpack', 'ltp', 'mlc', 'nepim', 'netperf', 'netpipe',
		 'nuttcp', 'octane', 'oltp', 'openarena', 'packetdrill', 'pbzip2',
		 'perf-bench-numa-mem', 'perf-bench-sched-pipe', 'pft',
		 'phoronix-test-suite', 'pigz', 'pixz', 'plzip', 'postmark', 'pxz', 'qperf',
		 'reaim', 'sdf', 'siege', 'sockperf', 'speccpu', 'specjbb2013',
		 'specjbb2015', 'specpower', 'stutter', 'sunspider', 'tbench', 'tcrypt',
		 'thrulay', 'tlbflush', 'unixbench', 'vm-scalability', 'will-it-scale',
		 'xfstests', 'swap']
	LINUX_TESTCASES =
		['boot', 'audio', 'cpu-hotplug', 'ext4-frags', 'ftq', 'ftrace_onoff', 'fwq',
		 'galileo', 'irda-kernel', 'kernel_selftests', 'kvm-unit-tests',
		 'locktorture', 'mce-test',  'otc_kernel_qa-ts_ltp_ddt', 'piglit', 'pm-qa',
		 'qemu', 'rcutorture', 'suspend', 'trinity', 'ndctl']
	OTHER_TESTCASES =
		['0day-boot-tests', '0day-kbuild-tests', 'android-kpi', 'build-dpdk',
		 'build-android', 'convert-lkpdoc-to-html', 'convert-lkpdoc-to-html-css',
		 'health-stats', 'hwinfo', 'internal-lkp-service', 'ipmi-setup',
		 'lkp-bug', 'lkp-install-run', 'lkp-services', 'lkp-src', 'pack',
		 'pack-deps', 'borrow']

	def initialize
		@linux_perf_table = LinuxMResultRootTable.open(LINUX_PERF_TABLE)
		@linux_table = LinuxMResultRootTable.open(LINUX_TABLE)
		@other_table = MResultRootTable.open(OTHER_TABLE)

		@table_map = {
			LINUX_PERF_TABLE => @linux_perf_table,
			LINUX_TABLE => @linux_table,
			OTHER_TABLE => @other_table,
		}

		@testcase_map = {}
		LINUX_PERF_TESTCASES.each { |c|
			@testcase_map[c] = @linux_perf_table
		}
		LINUX_TESTCASES.each { |c|
			@testcase_map[c] = @linux_table
		}
		OTHER_TESTCASES.each { |c|
			@testcase_map[c] = @other_table
		}
	end

	def testcase_to_table(testcase)
		tbl = @testcase_map[testcase]
		raise "Unknow testcase: #{testcase}" unless tbl
		tbl
	end

	def tables()
		[@linux_perf_table, @linux_table, @other_table]
	end

	def linux_perf_table
		@linux_perf_table
	end

	def axes_to_table(axes)
		testcase_to_table(axes[TESTCASE_AXIS_KEY])
	end

	def new_node(axes)
		tbl = axes_to_table axes
		tbl.new_node axes
	end

	def open_node(axes)
		tbl = axes_to_table axes
		tbl.open_node axes
	end

	def open_node_from_omrt(omrt)
		open_node omrt.axes
	end

	def open_node_from_omrt_dir(omrt_dir)
		omrt = MResultRoot.new(omrt_dir)
		open_node_from_omrt omrt
	end

	class << self
		def create_tables_layout(force = false)
			MResultRootTable.create_layout(OTHER_TABLE, force)
			LinuxMResultRootTable.create_layout(LINUX_TABLE, force)
			LinuxMResultRootTable.create_layout(LINUX_PERF_TABLE, force)
		end
	end
end

def mrt_table_set()
	$mrt_table_set ||= MResultRootTableSet.new
end

class NMResultRootCollection
	def initialize(conditions = {})
		@conditions = {}
		conditions.each { |k, v|
			@conditions[k] = v.to_s
		}
		@date = nil
		@exact = false
	end

	include Enumerable
	include Property

	prop_accessor :exact

	def set(key, value)
		@conditions[key] = value.to_s
		self
	end

	def unset(key)
		@conditions.delete key
		self
	end

	def set_date(date)
		@date = date
	end

	def each(&b)
		block_given? or return enum_for(__method__)

		table_each = ->tbl{
			col = DataStore::Collection.new tbl, @conditions
			col.set_date(@date).set_exact(@exact)
			col.each(&b)
		}

		testcase = @conditions[TESTCASE_AXIS_KEY]
		if testcase
			tbl = mrt_table_set.testcase_to_table testcase
			table_each.(tbl)
		else
			mrt_table_set.tables.each { |tbl|
				table_each.(tbl)
			}
		end
	end
end

def nmresult_root_collections_for_axis(_rt, axis_key, values)
	axes = _rt.axes
	values.map { |v|
		c = NMResultRootCollection.new axes
		c.set(axis_key, v.to_s)
	}
end

def nresult_root_fsck
	col = NMResultRootCollection.new
	col.each { |mrt|
		puts mrt.path
		if Dir.exist?(mrt.path)
			yield(mrt) if block_given?
		else
			mrt.delete
		end
	}
end
