LKP_SRC ||= ENV['LKP_SRC']

require "digest/sha1"
require "fileutils"

require "#{LKP_SRC}/lib/common.rb"
require "#{LKP_SRC}/lib/property.rb"
require "#{LKP_SRC}/lib/yaml.rb"

module DataStore
	class Map
		NAME = :name
		AXIS_KEYS = :axis_keys
		SUPPRESS_LAST = :suppress_last
		PROPS = [NAME, AXIS_KEYS, SUPPRESS_LAST]
		ALL_OTHERS_KEY = :__all_others__

		include Property
		prop_accessor *PROPS

		def initialize(params)
			from_data params
		end

		def from_data(params)
			PROPS.each { |k|
				set_prop k, params[k]
			}
		end

		def to_data
			params = {}
			PROPS.each { |k|
				params[k] = get_prop k
			}
		end
	end

	class Layout
		CONFIG_FILE = 'layout.yaml'.freeze
		MATRIX_FILE = 'matrix.json'.freeze
		INDEX_LOCK_FILE = '.lock'.freeze
		MAPS = :maps
		COMPRESS_MATRIX = :comrpess_matrix

		prop_reader :maps
		prop_accessor :compress_matrix

		def initialize(path, create_new = false)
			@path = path
			if create_new
				@maps = []
			else
				load
			end
		end

		private

		def load
			elayout = load_yaml path(CONFIG_FILE)
			from_data elayout
		end

		def from_data(elayout)
			@maps = []
			elayout[MAPS].each { |em|
				add_map(em)
			}
			@compress_matrix = elayout[COMPRESS_MATRIX]
		end

		def to_data
			{
				MAPS => @maps.map { |m| m.to_data },
				COMPRESS_MATRIX => @comparess_matrix,
			}
		end

		def path(*subs)
			File.join @path, *subs
		end

		public

		def save
			mkdir_p @path
			elayout = to_data
			save_yaml elayout, path(CONFIG_FILE)
		end

		def axes_to_string(axes)
			axes.each.map { |k, v|
				"#{k}=#{v}"
			}.sort!.join('/')
		end

		def axes_from_string(str)
			as = {}
			kvs = str.split '/'
			kvs.each { |kv|
				k, v = kv.split '='
				as[k] = v
			}
			as
		end

		def axes_str_hash(axes_str)
			Digest::SHA1.hexdigest axes_str
		end

		def axes_hash(axes)
			axes_str_hash axes_to_string(axes)
		end

		def storage_hash_path(hash_str)
			path 'storage', hash_str[0...2], hash_str
		end

		def storage_path(axes)
			storage_hash_path axes_hash(axes)
		end

		def matrix_path(node)
			mf = MATRIX_FILE
			mf += '.gz' if @comparess_matrix
			node.path(mf)
		end

		def add_map(params)
			@maps << Map.new(params)
		end

		def map_dir(map, values)
			path 'maps', map.name, *values
		end

		def calc_all_others_map_value(axes, axes_keys)
			as = deepcopy(axes)
			axes_keys.each { |k|
				next if k == Map::ALL_OTHERS_KEY
				as.delete k
			}
			as.each.map { |k, v|
				"#{k}=#{v}"
			}.sort!.join('-')
		end

		def calc_map_dir(map, node)
			axes = node.axes
			map_values = map.axis_keys.map { |k|
				if k == Map::ALL_OTHERS_KEY
					calc_all_others_map_value axes, map.axis_keys
				else
					axes.fetch(k, '_').to_s
				end
			}
			map_dir(map, map_values)
		end

		def make_map(map, node)
			mdir = calc_map_dir map, node
			if map.suppress_last
				mkdir_p File.dirname(mdir)
				FileUtils.rm_rf mdir
			else
				mkdir_p mdir
			end
			make_relative_symlink(storage_path(node.axes), mdir)
		end

		def delete_map(map, node)
			mdir = calc_map_dir map, node
			if map.suppress_last
				mpath = mdir
			else
				mpath = File.join mdir, axes_hash(node.axes)
			end
			FileUtils.rm_f(mpath)
		end

		def index_dir
			path 'index'
		end

		def index_file(date)
			File.join index_dir, str_date(date)
		end

		def index_lock_file
			File.join index_dir, INDEX_LOCK_FILE
		end

		def index(node)
			@maps.each { |m|
				make_map(m, node)
			}
			mkdir_p index_dir
			with_flock(index_lock_file) {
				File.open(index_file(node.create_time), "a") { |f|
					f.write("#{axes_to_string node.axes}\n")
				}
			}
		end

		def delete_index(node)
			@maps.each { |m|
				delete_map(m, node)
			}
			with_flock(index_lock_file) {
				as_str = axes_to_string node.axes
				idxf = index_file node.create_time
				system "sed -i -e '\\?^#{as_str}$?d' #{idxf}"
			}
		end

		def index_glob
			File.join index_dir, DATE_GLOB
		end

		def all_index_files
			files = Dir.glob(index_glob)
			files.sort!
			files.reverse!
			files
		end
	end

	class << Layout
		private :new

		singleton_class.include AddCachedMethod
		add_cached_method :new

		def open(path)
			path = canonicalize_path path
			self.cached_new path, path
		end

		def create_new(path)
			path = canonicalize_path path
			self.cached_new path, path, true
		end

		def exists?(path)
			File.exists? File.join(path, self::CONFIG_FILE)
		end

		def node_dir_to_table_dir(node_dir)
			storage_dir = File.dirname(File.dirname(node_dir))
			if File.basename(storage_dir) == 'storage'
				File.dirname(storage_dir)
			elsif symlink? node_dir
				# symlink in maps
				target = File.readlink(node_dir)
				node_dir = File.join File.dirname(node_dir), target
				node_dir = canonicalize_path node_dir
				node_dir_to_table_dir node_dir
			end
		end
	end

	class Node
		CREATE_TIME = 'create_time'
		AXES = :axes
		DESC = :desc
		STAT_KEY = :key
		STAT_VALUE = :value

		DESC_FILE = 'desc.yaml'
		START_INDEX_FILE = '.start_index'
		INDEXED_FILE = '.indexed'
		LOCK_FILE = '.lock'

		include DirObject
		prop_reader :table, :axes

		private

		def initialize(table)
			@table = table
		end

		def layout
			@table.layout
		end

		def __save_matrix(m)
			save_json m, layout.matrix_path(self)
		end

		def __save_desc(desc)
			desc[AXES] = @axes
			save_yaml desc, path(DESC_FILE)
		end

		public

		def init_from_axes(axes)
			@axes = deepcopy(axes).freeze
			@path = layout.storage_path(@axes)
		end

		def init_from_path(dir)
			@path = dir
			desc = load_yaml(path(DESC_FILE))
			@axes = desc[AXES]
			@axes.freeze
		end

		def hash
			layout.axes_hash(axes)
		end

		def load_matrix
			try_load_json(layout.matrix_path(self)) || {}
		end

		def save_matrix(m)
			mkdir_p @path
			with_flock(path(LOCK_FILE)) {
				__save_matrix m
			}
		end

		def update_matrix
			mkdir_p @path
			with_flock(path(LOCK_FILE)) {
				m = load_matrix
				yield m
				__save_matrix m
			}
		end

		def load_desc
			desc_file = path(DESC_FILE)
			if File.exists? desc_file
				desc = load_yaml desc_file
			else
				desc = {}
			end
			desc[AXES] = @axes
			desc
		end

		def save_desc(desc)
			mkdir_p @path
			with_flock(path(LOCK_FILE)) {
				__save_desc desc
			}
		end

		def update_desc
			mkdir_p @path
			with_flock(path(LOCK_FILE)) {
				desc = load_desc
				yield desc if block_given?
				__save_desc desc
			}
		end

		def create_storage_link(src)
			mkdir_p File.dirname(@path)
			FileUtils.symlink(src, @path, force: true)
		end

		def calc_create_time
			if files = Dir[path('*')]
				return files.map { |f| File.mtime f }.sort!.first
			else
				Time.now
			end
		end

		def create_time
			unless @create_time
				desc = load_desc
				@create_time = desc[CREATE_TIME]
			end
			@create_time
		end

		def index(force = false)
			indexed_file = path(INDEXED_FILE)
			FileUtils.rm_f(indexed_file) if force
			indexed = File.exists? indexed_file
			return if indexed

			update_desc { |desc|
				desc[CREATE_TIME] ||= calc_create_time
			}

			start_index_file = path(START_INDEX_FILE)
			start_index = File.exists? start_index_file
			if start_index
				if collection.first
					FileUtils.touch indexed_file
					return
				end
			else
				FileUtils.touch start_index_file
			end

			layout.index(self)
			FileUtils.touch indexed_file
		end

		def delete_index
			indexed_file = path(INDEXED_FILE)
			return unless File.exists? indexed_file
			layout.delete_index(self)
			FileUtils.rm_f indexed_file
			FileUtils.rm_f path(START_INDEX_FILE)
		end

		def each
			block_given? or return enum_for(__method__)

			as = @axes
			desc = load_desc
			matrix = load_matrix

			matrix.each { |k, v|
				stat = {
					AXES => as,
					DESC => desc,
					STAT_KEY => k,
					STAT_VALUE => v,
				}
				yield stat
			}
		end

		def collection
			c = Collection.new(table, axes)
			c.set_date create_time
		end

		def delete
			delete_index
			if File.symlink? @path
				FileUtils.rm_f @path
			else
				FileUtils.rm_rf @path
			end
		end
	end

	class << Node
		private :new

		def create_new(table, axes)
			n = new table
			n.init_from_axes axes
			n
		end

		def open(table, axes)
			n = new table
			n.init_from_axes axes
			n
		end

		def open_table_dir(table, dir)
			n = new table
			n.init_from_path dir
			n
		end

		def open_dir(dir)
			dir = canonicalize_path dir
			table = Table.open_from_node_dir dir
			open_table_dir table, dir
		end
	end

	class Collection
		include Enumerable

		def initialize(table, conditions = {})
			@table = table
			@conditions = deepcopy(conditions)
		end

		def set(key, value)
			@conditions[key] = value
			self
		end

		def unset(key, value)
			@conditions.delete key
			self
		end

		def set_date(date)
			@date = date
			self
		end

		def index_files
			layout = @table.layout
			if @date
				fn = layout.index_file(@date)
				if File.exists? fn
					[fn]
				else
					[]
				end
			else
				layout.all_index_files
			end
		end

		def each_for_all
			index_files.each { |ifn|
				File.open(ifn) { |f|
					f.readlines.reverse!.each { |line|
						line = line.strip
						next if line.size == 0
						yield @table.open_node_from_index_line(line)
					}
				}
			}
		end

		def each(&b)
			block_given? or return enum_for(__method__)

			if @conditions.empty?
				each_for_all(&b)
				return
			end

			cond_arr = @conditions.to_a
			k0, v0 = cond_arr[0]
			grep_cmdline = "grep -e '#{k0}=#{v0}'"
			cond_arr.drop(1).each { |k, v|
				grep_cmdline += " | grep -e '#{k}=#{v}'"
			}

			index_files.each { |ifn|
				`cat #{ifn} | #{grep_cmdline}`.lines.reverse!.each { |line|
					line = line.strip
					next if line.size == 0
					yield @table.open_node_from_index_line(line)
				}
			}
		end

		def each_stat(&b)
			block_given? or return enum_for(__method__)

			each { |n|
				n.each(&b)
			}
		end
	end

	class Table
		prop_reader :layout

		def initialize(layout)
			@node_class = Node
			@layout = layout
		end

		def new_node(axes)
			@node_class.create_new self, axes
		end

		def open_node(axes)
			@node_class.open self, axes
		end

		def open_node_dir(dir)
			@node_class.open_table_dir self, dir
		end

		def open_node_from_index_line(line)
			open_node @layout.axes_from_string(line)
		end

		def delete_node(node)
			node.delete
		end

		def collection(conditions = {})
			Collection.new(self, conditions)
		end
	end

	class << Table
		private :new

		singleton_class.include AddCachedMethod
		add_cached_method :new

		def open(path)
			path = canonicalize_path path
			layout = Layout.open path
			cached_new path, layout
		end

		def open_from_node_dir(node_dir)
			node_dir = canonicalize_path node_dir
			path = Layout.node_dir_to_table_dir node_dir
			path = canonicalize_path path
			cached_new path, path
		end
	end

	def self.test
		tbl_path = File.join(ENV['HOME'], 'tbl1')
		FileUtils.rm_rf tbl_path
		layout = Layout.create_new tbl_path
		layout.add_map(Map::NAME => 'default',
			       Map::AXIS_KEYS => ['a', 'b', Map::ALL_OTHERS_KEY],
			       Map::SUPPRESS_LAST => true)
		layout.add_map(Map::NAME => 'c',
			       Map::AXIS_KEYS => ['c'])
		layout.save
		tbl = Table.open tbl_path
		0.upto(3) { |a|
			'h'.upto('k') { |b|
				n = tbl.new_node({'a' => a, 'b' => b, 'c' => 2})
				m = n.load_matrix
				m['s1'] = [1, 2, 3]
				m['s2'] = [4, a, b]
				n.save_matrix m
				n.index
			}
		}
		puts "all nodes:"
		tbl.collection.each { |n|
			puts "  node: #{n.axes}: #{n.load_matrix}"
		}
		puts "collection: 'b' => 'i'"
		coll = Collection.new tbl, 'b' => 'i'
		coll.each_stat { |s|
			puts "  stat: #{s}"
		}
	end
end
