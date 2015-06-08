# coding: utf-8
LKP_SRC ||= ENV['LKP_SRC']
require "#{LKP_SRC}/lib/common.rb"
require "#{LKP_SRC}/lib/enumerator.rb"
require "#{LKP_SRC}/lib/stats.rb"
require "#{LKP_SRC}/lib/tests.rb"
require "#{LKP_SRC}/lib/result_root.rb"

module Compare
	ABS_WIDTH = 10
	REL_WIDTH = 10
	ERR_WIDTH = 6

	COMPARE_AXIS_KEYS = :compare_axis_keys
	MRESULT_ROOTS = :_result_roots
	ALL_STATS = :all_stats
	SET_STAT_KEYS = :set_stat_keys
	INCLUDE_STATS = :include_stats
	GROUP_BY_STAT = :group_by_stat

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

	AXES_AS_NUM = :axes_as_num
	AXES_PREFIX = :axes_prefix
	SORT = :sort

	class Groups
		private

		def initialize(params)
			@params = params
			group
		end

		def calc_common_axes(axes)
			as = deepcopy(axes)
			@params[COMPARE_AXIS_KEYS].each { |ak| as.delete ak }
			as
		end

		def group
			map = {}
			@params[MRESULT_ROOTS].each { |_rt|
				as = calc_common_axes(_rt.axes)
				as.freeze
				cg = map[as] ||= Group.new(@params, as)
				cg.add_mresult_root _rt
			}
			@compare_groups = map.values
			@compare_groups.reject! { |cg| cg._result_roots.size < 2 }
		end

		public

		attr_reader :compare_groups

		def each_group(&b)
			block_given? or return enum_for(__method__)

			@compare_groups.each &b
		end

		def each_changed_stat(&b)
			block_given? or return enum_for(__method__)

			@compare_groups.each { |g|
				g.each_changed_stat &b
			}
		end
	end

	class Group
		private

		def initialize(params, common_axes)
			@params = params
			@common_axes = common_axes
			@_result_roots = []
		end

		def calc_compare_axeses
			compare_axis_keys = @params[COMPARE_AXIS_KEYS]
			@_result_roots.map { |_rt|
				_rt.axes.select { |k,v| compare_axis_keys.index k }
			}
		end

		public

		attr_reader :_result_roots, :common_axes

		def add_mresult_root(_rt)
			@_result_roots << _rt
		end

		def compare_axeses
			@compare_axeses ||= calc_compare_axeses
		end

		def matrixes
			@matrixes ||= _result_roots.map { |_rt| _rt.matrix.freeze }
		end

		def complete_matrixes
			unless @complete_matrixes
				cms = _result_roots.zip(matrixes).map { |_rt, m|
					_rt.complete_matrix m
				}
				@complete_matrixes = cms
			end
			@complete_matrixes
		end

		def calc_all_stats
			stat_keys = []
			matrixes.each { |m|
				stat_keys |= m.keys
			}
			stat_keys.delete 'stats_source'
			@changed_stats = stat_keys
		end

		def set_stat_keys(stat_keys)
			@changed_stats = stat_keys
		end

		def calc_changed_stats
			changed_stats = []
			mfile0 = @_result_roots[0].matrix_file
			@_result_roots.drop(1).each { |_rt|
				changed_stats |= get_changed_stats(_rt.matrix_file, mfile0).keys
			}
			@changed_stats = changed_stats
		end

		def include_stats(stat_res)
			astats = all_stats
			matched = stat_res.map { |sre|
				re = Regexp.new(sre)
				astats.select { |stat| re.match stat }
			}.flatten
			@changed_stats |= matched
		end

		def changed_stats
			@changed_stats || calc_all_stats
		end

		def each_changed_stat
			block_given? or return enum_for(__method__)

			ms = matrixes
			cms = complete_matrixes
			runs = ms.map { |m| matrix_cols m }
			cruns = cms.map { |m| matrix_cols m }
			changed_stats.each { |stat_key|
				failure = is_failure stat_key
				tms = failure ? ms : cms
				truns = failure ? runs : cruns
				stat = {
					STAT_KEY => stat_key,
					FAILURE => failure,
					GROUP => self,
					VALUES => tms.map { |m| m[stat_key] },
					RUNS => truns
				}
				yield stat
			}
		end
	end

	class GroupData
		def initialize(group, stat_enum)
			@group = group
			@stat_enum = stat_enum
		end

		attr_reader :group, :stat_enum

		def matrix(data_key = AVGS)
			m = {}
			@stat_enum.each { |stat|
				m[stat[STAT_KEY]] = stat[data_key]
			}
			m
		end

		def common_axes
			@group.common_axes
		end

		def common_axes_string(sep1 = '-', sep2 = '=')
			common_axes.map { |k, v|
				"#{k}#{sep2}#{v}"
			}.join sep1
		end

		def common_axes_value_string(sep = '-')
			common_axes.values.join sep
		end

		def compare_axeses
			@group.compare_axeses
		end

		def matrix_with_axes(data_key = nil, params = {})
			cas = compare_axeses
			cas_keys = cas[0].keys

			data_key ||= AVGS
			axes_as_num = params.fetch(AXES_AS_NUM, true)
			prefix = params.fetch(AXES_PREFIX, "")
			sort_key = params.fetch(SORT, prefix + cas_keys[0])

			axis_converter = lambda { |axis_key|
				if axes_as_num && (axes_as_num == true ||
						   axes_as_num.index(axis_key))
					return method(:string_to_num)
				else
					return ->x{x}
				end
			}

			m = {}
			cas_keys.each { |axis_key|
				conv = axis_converter.(axis_key)
				m[prefix + axis_key] = cas.map { |as|
					conv.(as[axis_key])
				}
			}
			m.merge! matrix(data_key)
			m = sort_matrix(m, sort_key) if sort_key
			m
		end
	end

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

	def self.do_compare(params)
		groups = Groups.new(params)

		groups.each_group { |g|
			if params[ALL_STATS]
				g.calc_all_stats
			elsif params[SET_STAT_KEYS]
				g.set_stat_keys params[SET_STAT_KEYS]
			else
				g.calc_changed_stats
				include_stats = params[INCLUDE_STATS]
				if include_stats
					g.include_stats(include_stats)
				end
			end
		}

		data = groups.each_group.map { |g|
			stat_enum = g.each_changed_stat.feach(method(:calc_stat_change))

			GroupData.new(g, stat_enum)
		}

		data
	end

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
		common_axes = group.common_axes
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
		nr_header = group._result_roots.size - 1
		failure, perf = stat_enum.partition { |stat| stat[FAILURE] }
		show_group_header group

		unless failure.empty?
			show_failure_header(nr_header)
			failure.each { |stat|
				show_failure_change stat
				show_stat stat
			}
		end

		unless perf.empty?
			show_perf_header(nr_header)
			perf.each { |stat|
				show_perf_change stat
				show_stat stat
			}
		end

		puts
	end

	def self.show_by_group(compare_data)
		compare_data.each { |gd|
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

	def self.show_by_stats(compare_data)
		stat_enums = compare_data.map { |d|
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
				printf "  %s\n", stat[GROUP].common_axes.values.join('/')
			}
		}
	end

	def self.show_compare_data(compare_data, params)
		if params[GROUP_BY_STAT]
			show_by_stats(compare_data)
		else
			show_by_group(compare_data)
		end
	end

	def self.compare(params)
		data = do_compare(params)
		show_compare_data(data, params)
	end

	def self.compare_commits(commits, params_in = {})
		# calc compare groups
		# calc change stats
		# calc stat change
		# group result
		# output
		_result_roots = commits.map { |c| MResultRootCollection.new('commit' => c).to_a }.flatten
		compare_axis_keys = ['commit']
		params = {
			MRESULT_ROOTS => _result_roots,
			COMPARE_AXIS_KEYS => compare_axis_keys
		}.merge(params_in)
		compare(params)
	end

	def self.test_compare_commits
		commits = ['f5c0a122800c301eecef93275b0c5d58bb4c15d9', '3a8b36f378060d20062a0918e99fae39ff077bf0']
		compare_axis_keys = ['commit', 'rwmode']
		pager {
			#compare_commits(commits,
			#		 ALL_STATS => true,
			#		 GROUP_BY_STAT => true)
			compare_commits(commits, ALL_STATS => false,
					GROUP_BY_STAT => false,
					COMPARE_AXIS_KEYS => compare_axis_keys)
		}
	end

	def self.test_incomplete_run
		_rt_ = '/result/lkp-sb02/fileio/performance-600s-100%-1HDD-ext4-64G-1024f-seqrd-sync/debian-x86_64-2015-02-07.cgz/x86_64-rhel/'
		rts_ = ['9eccca0843205f87c00404b663188b88eb248051', '06e5801b8cb3fc057d88cb4dc03c0b64b2744cda'].
			     map { |c| MResultRoot.new(_rt_ + c) }
		rts_.each { |_rt|
			puts "#{_rt.runs}"
		}
		params = {
			MRESULT_ROOTS => rts_,
			COMPARE_AXIS_KEYS => ['commit'],
			ALL_STATS => false,
		}
		page {
			compare(params)
		}
	end

	def self.test_compare_aim7
		_result_roots = MResultRootCollection.new(
			'commit' => '39a8804455fb23f09157341d3ba7db6d7ae6ee76',
			'tbox_group' => 'grantley',
			'test' => 'ram_copy',
		).to_a
		compare_axis_keys = ['load']
		params = {
			MRESULT_ROOTS => _result_roots,
			COMPARE_AXIS_KEYS => compare_axis_keys,
		}
		pager {
			compare(params)
		}
	end
end
