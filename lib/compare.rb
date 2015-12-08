# coding: utf-8
LKP_SRC ||= ENV['LKP_SRC']
require "#{LKP_SRC}/lib/common.rb"
require "#{LKP_SRC}/lib/enumerator.rb"
require "#{LKP_SRC}/lib/stats.rb"
require "#{LKP_SRC}/lib/tests.rb"
require "#{LKP_SRC}/lib/result_root.rb"

class AxesGrouper
	include Property
	prop_with :group_axis_keys, :axes_data

	private

	def calc_common_axes(axes)
		as = deepcopy(axes)
		group_axis_keys.each { |k| as.delete k }
		as
	end

	public

	def group
		map = {}
		@axes_data.each { |d|
			as = calc_common_axes d.axes
			as.freeze
			map[as] ||= AxesGroup.new self, as
			map[as].add_axes_datum d
		}
		groups = map.values
		groups
	end

	def global_common_axes
		as = deepcopy(@axes_data.first.axes)
		@axes_data.drop(1).each { |ad|
			ad_as = ad.axes
			as.select! { |k, v| v && v == ad_as[k] }
		}
		as
	end
end

class AxesGroup
	prop_with :axes, :axes_data

	def initialize(grouper, common_axes)
		@grouper = grouper
		@axes = common_axes
		@axes_data = []
	end

	def add_axes_datum(datum)
		@axes_data << datum
	end

	def group_axeses
		group_axis_keys = @grouper.group_axis_keys
		@axes_data.map { |d|
			d.axes.select { |k,v| group_axis_keys.index k }
		}
	end
end

module Compare
	ABS_WIDTH = 10
	REL_WIDTH = 10
	ERR_WIDTH = 6

	STAT_KEY = :stat_key
	FAILURE = :failure
	GROUP = :group
	VALUES = :values
	RUNS = :runs

	STAT_BASE = :stat_base
	AVGS = :avgs
	STDDEVS = :stddevs
	FAILS = :fails
	CHANGES = :changes

	RUNS_STAT_KEY = 'runs'
	COMPLETE_RUNS_STAT_KEY = 'runs.complete'
	RUNS_STAT_KEYS = [RUNS_STAT_KEY, COMPLETE_RUNS_STAT_KEY]

	class Comparer
		include Property
		# following properties are parameters for compare
		prop_reader :stat_calc_funcs
		prop_with :mresult_roots, :compare_axis_keys,
							:use_all_stat_keys, :use_stat_keys,
							:use_testcase_stat_keys,
							:include_stat_keys, :include_all_failure_stat_keys,
							:filter_stat_keys, :filter_testcase_stat_keys,
							:group_by_stat, :show_empty_group, :compact_show

		private

		def initialize(params = nil)
			set_params params
			@stat_calc_funcs = [Compare.method(:calc_stat_change)]
			@show_empty_group = false
		end

		public

		def set_params(params)
			set_prop *params.flatten if params
			self
		end

		def compare_groups
			grouper = AxesGrouper.new
			groups = grouper.set_axes_data(@mresult_roots).
				       set_group_axis_keys(@compare_axis_keys).
				       group
			groups.map { |g|
				next if g.axes_data.size < 2
				Group.new self, g
			}.compact
		end

		def global_common_axes
			grouper = AxesGrouper.new
			grouper.set_axes_data(@mresult_roots).
				global_common_axes
		end

		# stat calc func is a function object with signature:
		# stat -> <ignored>
		def add_stat_calc_funcs(*calcs)
			@stat_calc_funcs += calcs
		end

		def each_changed_stat(&b)
			block_given? or return enum_for(__method__)

			compare_groups.each { |g|
				g.each_changed_stat &b
			}
		end

		def do_compare
			compare_groups.map { |g|
				stat_enum = g.each_changed_stat
				stat_enum = Compare.sort_stats stat_enum
				GroupResult.new g, stat_enum
			}
		end

		def show_compare_result(compare_result)
			if group_by_stat
				Compare.show_by_stats compare_result
			else
				Compare.show_by_group compare_result
			end
		end

		# - select _result_roots: set_mresult_roots
		# - set compare axis: set_compare_axis
		# - get compare result: do_compare
		#   - group the result roots: compare_groups
		#   - calc changed stats keys: Group::calc_changed_stats
		#   - calc changes: in Group::each_changed_stat
		# - show compare result: show_compare_result
		def compare
			result = do_compare
			show_compare_result result
		end
	end

	class Group
		prop_reader :mresult_roots, :axes, :compare_axeses, :comparer

		private

		def initialize(comparer, axes_group)
			@comparer = comparer
			@axes = axes_group.axes
			@mresult_roots = axes_group.axes_data
			@compare_axeses = axes_group.group_axeses
		end

		public

		def matrixes
			@matrixes ||= mresult_roots.map { |_rt| _rt.matrix.freeze }
		end

		def complete_matrixes
			unless @complete_matrixes
				cms = mresult_roots.zip(matrixes).map { |_rt, m|
					_rt.complete_matrix m
				}
				@complete_matrixes = cms
			end
			@complete_matrixes
		end

		def runs
			matrixes.map { |m| matrix_cols m }
		end

		def complete_runs
			complete_matrixes.map { |m| matrix_cols m }
		end

		def get_all_stat_keys
			stat_keys = []
			matrixes.each { |m|
				stat_keys |= m.keys
			}
			stat_keys.delete 'stats_source'
			stat_keys
		end

		def _calc_changed_stat_keys
			changed_stat_keys = []
			mfile0 = @mresult_roots[0].matrix_file
			@mresult_roots.drop(1).each { |_rt|
				changes = get_changed_stats(_rt.matrix_file, mfile0)
				if changes
					changed_stat_keys |= changes.keys
				end
			}
			changed_stat_keys
		end

		def do_filter_stat_keys(stats, filters)
			filters.map { |sre|
				re = Regexp.new(sre)
				stats.select { |stat_key| re.match stat_key }
			}.flatten
		end

		def get_include_stat_keys
			stat_key_res = @comparer.include_stat_keys
			return [] unless stat_key_res
			do_filter_stat_keys get_all_stat_keys, stat_key_res
		end

		def filter_stat_keys(stats)
			filters = @comparer.filter_stat_keys
			return stats unless filters && !filter.empty?
			do_filter_stat_keys stats, filters
		end

		def get_include_all_failure_stat_keys
			return [] unless @comparer.include_all_failure_stat_keys
			get_all_stat_keys.select { |stat_key| is_failure stat_key }
		end

		def do_filter_testcase_stat_keys(stats)
			testcase = axes[TESTCASE_AXIS_KEY]
			if testcase
				testcase_time = "#{testcase}.time."
				stats.select { |k|
					k.start_with?(testcase) &&
						!k.start_with?(testcase_time)
				}
			else
				[]
			end
		end

		def get_testcase_stat_keys
			do_filter_testcase_stat_keys get_all_stat_keys
		end

		def filter_testcase_stat_keys(stats)
			do_filter_testcase_stat_keys stats
		end

		def calc_changed_stat_keys
			if @comparer.use_all_stat_keys
				stat_keys = get_all_stat_keys
			elsif @comparer.use_stat_keys
				stat_keys = @comparer.use_stat_keys
			elsif @comparer.use_testcase_stat_keys
				stat_keys = get_testcase_stat_keys
			else
				stat_keys = _calc_changed_stat_keys
			end
			stat_keys |= get_include_stat_keys
			stat_keys |= get_include_all_failure_stat_keys
			stat_keys = filter_stat_keys stat_keys
			if @comparer.filter_testcase_stat_keys
				stat_keys = filter_testcase_stat_keys stat_keys
			else
				stat_keys
			end
		end

		def changed_stat_keys
			@changed_stat_keys ||= calc_changed_stat_keys
		end

		def each_changed_stat
			block_given? or return enum_for(__method__)

			calc_funcs = @comparer.stat_calc_funcs
			ms = matrixes
			cms = complete_matrixes
			aruns = runs
			cruns = complete_runs
			changed_stat_keys.each { |stat_key|
				failure = is_failure stat_key
				tms = failure ? ms : cms
				truns = failure ? aruns : cruns
				stat = {
					STAT_KEY => stat_key,
					FAILURE => failure,
					GROUP => self,
					VALUES => tms.map { |m| m[stat_key] },
					RUNS => truns
				}
				calc_funcs.each { |calc_func|
					calc_func.(stat)
				}
				yield stat
			}
		end
	end

	class GroupResult
		def initialize(group, stat_enum)
			@group = group
			@stat_enum = stat_enum
		end

		prop_reader :group, :stat_enum

		def axes
			@group.axes
		end

		def axes_string(sep1 = '-', sep2 = '=')
			common_axes.map { |k, v|
				"#{k}#{sep2}#{v}"
			}.join sep1
		end

		def axes_value_string(sep = '-')
			common_axes.values.join sep
		end

		def compare_axeses
			@group.compare_axeses
		end

		def matrix_exporter
			MatrixExporter.new self
		end
	end

	class GroupResult::MatrixExporter
		include Property
		prop_with :data_type, :include_axes, :axes_as_num,
			  :axis_prefix, :sort, :sort_stat_key,
			  :include_runs
		def initialize(group_result)
			@group_result = group_result
			@data_type = AVGS
			@axes_as_num = true
			@axis_prefix = ""
			@sort = true
		end

		def matrix
			m = {}
			@group_result.stat_enum.each { |stat|
				m[stat[STAT_KEY]] = stat[@data_type]
			}
			if @include_runs
				g = @group_result.group
				m[RUNS_STAT_KEY] = g.runs
				m[COMPLETE_RUNS_STAT_KEY] = g.complete_runs
			end
			m
		end

		def matrix_with_axes
			cas = @group_result.compare_axeses
			cas_keys = cas[0].keys
			if @sort
				sort_key = @sort_stat_key ||
					   @axis_prefix + cas_keys[0]
			end
			axis_converter = lambda { |axis_key|
				if @axes_as_num && (@axes_as_num == true ||
						    @axes_as_num.index(axis_key))
					return method(:string_to_num)
				else
					return ->x{x}
				end
			}

			m = {}
			cas_keys.each { |axis_key|
				conv = axis_converter.(axis_key)
				m[@axis_prefix + axis_key] = cas.map { |as|
					conv.(as[axis_key])
				}
			}
			m.merge!(matrix)
			m = sort_matrix(m, sort_key) if @sort
			m
		end

		def call
			if @include_axes
				matrix_with_axes
			else
				matrix
			end
		end
	end

	## Stat Calculation Functions

	def self.calc_failure_fail(stat)
		return unless stat[FAILURE]
		stat[FAILS] = stat[VALUES].map { |v|
			v ? v.sum : 0
		}
	end

	def self.calc_failure_change(stat)
		return unless stat[FAILURE]
		fs = stat[FAILS]
		runs = stat[RUNS]
		reproduce0 = fs[0].to_f / runs[0]
		stat[CHANGES] = fs.drop(1).each_with_index.map { |f, i|
			100 * (f.to_f / runs[i] - reproduce0)
		}
	end

	def self.calc_avg_stddev(stat)
		return if stat[FAILURE]
		vs = stat[VALUES]
		stat[AVGS] = vs.map { |v| v && v.size > 0 ? v.average : 0 }
		stat[STDDEVS] = vs.map { |v| v && v.size > 1 ? v.standard_deviation : -1 }
	end

	def self.calc_perf_change(stat)
		return if stat[FAILURE]
		avgs = stat[AVGS]
		avg0 = avgs[0]
		stat[CHANGES] = avgs.drop(1).map { |avg|
			100.0 * (avg - avg0) / avg0
		}
	end

	def self.calc_stat_change(stat)
		calc_failure_fail stat
		calc_failure_change stat
		calc_avg_stddev stat
		calc_perf_change stat
	end

	## Compare result renderer

	def self.sort_stats(stat_enum)
		stats = stat_enum.to_a
		stat_base_map = {}
		stats.each { |stat|
			base = stat_key_base stat[STAT_KEY]
			stat[STAT_BASE] = base
			stat_base_map[base] ||= stat[FAILURE] ? -10000 : 0
			stat_base_map[base] += 1
		}
		AllTests.each { |test|
			c = stat_base_map[test]
			if c and c > 0
				stat_base_map[test] = 0
			end
		}
		stats.sort_by! { |stat| [stat_base_map[stat[STAT_BASE]], stat[STAT_KEY]] }
		stats.each
	end

	def self.show_failure_change(stat)
		return unless stat[FAILURE]
		fails = stat[FAILS]
		changes = stat[CHANGES]
		runs = stat[RUNS]
		fails.each_with_index { |f, i|
			unless i == 0
				printf "%#{REL_WIDTH}.0f%% ", changes[i-1]
			end
			if f == 0
				printf "%#{ABS_WIDTH+1}s", ' '
			else
				printf "%#{ABS_WIDTH+1}d", f
			end
			printf ":%-#{ERR_WIDTH-2}d", runs[i]
		}
	end

	def self.show_perf_change(stat)
		return if stat[FAILURE]
		avgs = stat[AVGS]
		stddevs = stat[STDDEVS]
		changes = stat[CHANGES]
		avgs.each_with_index { |avg, i|
			unless i == 0
				p = changes[i-1]
				fmt = p.abs < 100000 ? '.1f' : '.2g'
				printf "%+#{REL_WIDTH}#{fmt}%% ", p
			end
			if avg.abs < 1000
				fmt = '.2f'
			elsif avg.abs > 100000000
				fmt = '.4g'
			else
				fmt = 'd'
			end
			printf "%#{ABS_WIDTH}#{fmt}", avg
			stddev = stddevs[i]
			if stddev
				stddev = 100 * stddev / avg if avg != 0
				printf " ±%#{ERR_WIDTH-3}d%%", stddev
			else
				printf " " * ERR_WIDTH
			end
		}
	end

	def self.show_stat(stat)
		printf "  %s\n", stat[STAT_KEY]
	end

	def self.show_group_header(group)
		common_axes = group.axes
		compare_axeses = group.compare_axeses
		puts "========================================================================================="
		printf "%s:\n", common_axes.keys.join('/')
		printf "  %s\n\n", common_axes.values.join('/')
		printf "%s: \n", compare_axeses[0].keys.join('/')
		compare_axeses.each { |compare_axes|
			printf "  %s\n", compare_axes.values.join('/')
		}
		puts
		first_width = ABS_WIDTH + ERR_WIDTH
		width = first_width + REL_WIDTH
		printf "%#{first_width}s ", compare_axeses[0].values.join('/')[0...first_width]
		compare_axeses.drop(1).each { |compare_axes|
			printf "%#{width}s ", compare_axes.values.join('/')[0...width]
		}
		puts
		printf "-" * first_width + ' '
		compare_axeses.drop(1).size.times {
			printf "-" * width + ' '
		}
		puts
	end

	def self.compact_show_group_header(group)
		common_axes = group.axes
		puts common_axes.map { |k, v| "#{k}=#{v}" }.join("/")
	end

	def self.show_perf_header(n = 1)
		# (ABS_WIDTH + ERR_WIDTH)   (2 + REL_WIDTH + ABS_WIDTH + ERR_WIDTH)
		#      |<-------------->|   |<--------------------------->|
		printf '         %%stddev' + '     %%change         %%stddev' * n + "\n"
		printf '             \  ' + '        |                \  ' * n + "\n"
	end

	def self.show_failure_header(n = 1)
		printf '       fail:runs' + '  %%reproduction    fail:runs' * n + "\n"
		printf '           |    ' + '         |             |    ' * n + "\n"
	end

	def self.show_group(group, stat_enum)
		compact_show = group.comparer.compact_show

		failure, perf = stat_enum.partition { |stat| stat[FAILURE] }

		if failure.empty? && perf.empty? && !group.comparer.show_empty_group
			return
		end

		if compact_show
			compact_show_group_header group
		else
			show_group_header group
		end
		nr_header = group.mresult_roots.size - 1

		unless failure.empty?
			show_failure_header(nr_header) unless compact_show
			failure.each { |stat|
				show_failure_change stat
				show_stat stat
			}
		end

		unless perf.empty?
			show_perf_header(nr_header) unless compact_show
			perf.each { |stat|
				show_perf_change stat
				show_stat stat
			}
		end

		puts
	end

	def self.show_by_group(compare_result)
		compare_result.each { |gd|
			show_group gd.group, gd.stat_enum
		}
	end

	def self.group_by_stat(stat_enum)
		stat_map = {}
		stat_enum.each { |stat|
			key = stat[STAT_KEY]
			stat_map[key] ||= []
			stat_map[key] << stat
		}
		stat_map
	end

	def self.show_by_stats(compare_result)
		stat_enums = compare_result.map { |d|
			sort_stats d.stat_enum
		}
		stat_enum = EnumeratorCollection.new(*stat_enums)
		stat_map = group_by_stat(stat_enum)
		stat_map.each { |stat_key, stats|
			puts "#{stat_key}:"
			stats.each { |stat|
				if stat[FAILURE]
					show_failure_change stat
				else
					show_perf_change stat
				end
				printf "  %s\n", stat[GROUP].axes.values.join('/')
			}
		}
	end

	## Helper functions

	def self.commits_comparer(commits, params = nil)
		_result_roots = commits.map { |c|
			MResultRootCollection.new(COMMIT_AXIS_KEY => c.to_s).to_a
		}.flatten
		compare_axis_keys = [COMMIT_AXIS_KEY]
		comparer = Comparer.new
		comparer.set_mresult_roots _result_roots
		comparer.set_compare_axis_keys compare_axis_keys
		comparer.set_params params
	end

	def self.compare_commits(commits, params = nil)
		comparer = commits_comparer commits, params
		comparer.compare
	end

	def self.ncommits_comparer(commits, params = nil)
		_rts = commits.map { |c|
			NMResultRootCollection.new(COMMIT_AXIS_KEY => c.to_s).to_a
		}.flatten
		compare_axis_keys = [COMMIT_AXIS_KEY]
		comparer = Comparer.new
		comparer.set_mresult_roots _rts
		comparer.set_compare_axis_keys compare_axis_keys
		comparer.set_params params
	end

	def self.ncompare_commits(commits, params = nil)
		comparer = ncommits_comparer commits, params
		comparer.compare
	end

	def self.perf_comparer(commits)
		_rts = commits.map { |c|
			DataStore::Collection.new(mrt_table_set.linux_perf_table, 'commit' => c.to_s).to_a
		}.flatten
		_rts.select! { |_rt|
			axes = _rt.axes
			testcase = axes[TESTCASE_AXIS_KEY]
			next false if testcase == 'xfstests' || testcase == 'autotest'
			tbox = axes[TBOX_GROUP_AXIS_KEY]
			next false if tbox.start_with? 'vm-'
			true
		}
		compare_axis_keys = [COMMIT_AXIS_KEY]
		comparer = Comparer.new
		comparer.set_mresult_roots(_rts).
			set_compare_axis_keys(compare_axis_keys).
			set_filter_testcase_stat_keys(true).
			set_compact_show(true)
	end

	def self.perf_compare(commits)
		comparer = perf_comparer commits
		comparer.compare
	end

	## Test functions

	def self.test_compare_commits
		commits = ['f5c0a122800c301eecef93275b0c5d58bb4c15d9', '3a8b36f378060d20062a0918e99fae39ff077bf0']
		comparer = commits_comparer commits
		comparer.set_compare_axis_keys([COMMIT_AXIS_KEY, 'rwmode']).
			set_use_all_stats(false).
			set_group_by_stat(false)

		pager {
			comparer.compare
		}
	end

	def self.test_incomplete_run
		_rt = '/result/lkp-sb02/fileio/performance-600s-100%-1HDD-ext4-64G-1024f-seqrd-sync/debian-x86_64-2015-02-07.cgz/x86_64-rhel/'
		_rts = ['9eccca0843205f87c00404b663188b88eb248051', '06e5801b8cb3fc057d88cb4dc03c0b64b2744cda'].
			     map { |c| MResultRoot.new(_rt + c) }
		_rts.each { |_rt|
			puts "#{_rt.runs}"
		}
		comparer = Comparer.new
		comparer.set_mresult_roots(_rts).
			set_compare_axis_keys([COMMIT_AXIS_KEY]).
			set_use_all_stats(false)
		page {
			comparer.compare
		}
	end

	def self.test_compare_aim7
		_result_roots = MResultRootCollection.new(
			COMMIT_AXIS_KEY => '39a8804455fb23f09157341d3ba7db6d7ae6ee76',
			'tbox_group' => 'grantley',
			'test' => 'ram_copy',
		).to_a
		compare_axis_keys = ['load']
		comparer = Comparer.new
		comparer.set_mresult_roots(_result_roots).
			set_compare_axis_keys(compare_axis_keys)
		pager {
			comparer.compare
		}
	end
end
