#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(__DIR__)

#         modprobe-2427  [008] ....   242.913825: vmalloc_alloc_area: start=0xffffc90001b07000, end=0xffffc90001b39000
#            bash-266   [001] ..s. 60321.215759: softirq_entry: vec=1 [action=TIMER]
#     TIME        CPU  TASK/PID         DURATION                  FUNCTION CALLS
#      |          |     |    |           |   |                     |   |   |   |
#    76.094231 |   0)   usemem-842   |               |  /* softirq_entry: vec=1 [action=TIMER] */

class TPSample
  RES_ARG = /([^{\[(=,: \t\n]+)=([^}\])=,: \t\n]+)/
  RE_SAMPLE = /^\s*(.*)-(\d+)\s+\[(\d+)\]\s+\S+\s+([0-9.]+): ([^: ]+): (.*)$/
  RE_SAMPLE2 = /^\s*([0-9.]+)\s+\|\s+(\d).\s+(.+)-(\d+)\s+\|\s+([0-9.]*).+\|\s+\/\*\s([^: ]+): (.*)\s\*\/.*/

  getter :cmd, :pid, :cpu, :timestamp, :type, :raw_data, :data

  def initialize(cmd, pid, cpu, timestamp, type, raw_data, data)
    @cmd = cmd
    @pid = pid
    @cpu = cpu
    @timestamp = timestamp
    @type = type
    @raw_data = raw_data
    @data = data
  end

  def [](key)
    @data[key]
  end

  def conv_data(converter)
    converter.call(@data)
  end

  def self.parse(str)
    case str
    when RE_SAMPLE
      cmd = $1
      pid = $2.to_i
      cpu = $3.to_i
      timestamp = $4.to_f
      type = $5
      raw_data = $6
    when RE_SAMPLE2
      cmd = $3
      pid = $4.to_i
      cpu = $2.to_i
      timestamp = $1.to_f
      type = $6
      raw_data = $7
    end
    return if raw_data.nil?

    arg_pair_strs = raw_data.scan RES_ARG
    arg_pairs = arg_pair_strs.map do |regex| # do |k, v|
      [regex[1], regex[2]]                   # [k, v]
    end
    data = arg_pairs.to_h
    new cmd, pid, cpu, timestamp, type, raw_data, data
  end
end

class TPEventFormat
  RE_FMT = /^print fmt: "(.*)", /
  RE_NAME = /^name: ([^=,: \n]+)/
  RE_INT_FMT = /^(?:0[xX])?%.*[xud]$/

  @name : String

  getter :name

  def initialize(name, args_desc)
    @name = name
    conv = args_desc.not_nil!.map do |arg, format|
      if format =~ RE_INT_FMT
        [arg, Object.method(:Integer)]  #still need fix
      else
        [arg, ->(x) { x }]              #ruby lambda
      end
    end
    @args_conv = conv.to_h
  end

  def convert_data(data)
    data.each { |n, v| data[n] = @args_conv[n].call(v) }
  end

  def convert(sample)
    sample.conv_data(method(:convert_data))
  end

  def self.parse(file)
    name = nil
    file.each_line do |line|
      name ||= RE_NAME.match line
      fmt = RE_FMT.match line
      if fmt
        arg_pair_strs = fmt[1].scan TPSample::RES_ARG
        arg_pairs = arg_pair_strs.map do |regex|   # |k, v|
          [regex[1], regex[2]]                     # [k, v]
        end
        args = arg_pairs.to_h
      end
      name && fmt && (return new(name[1].strip, args))
    end
  end
end

class TPTrace
  def initialize(file : Array(String), fmts_dir = nil)
    @file = file
    @formats = Hash(String, TPEventFormat).new
    fmts_dir || return
    Dir.glob(File.join(fmts_dir, "*.fmt")).each do |fmt_fn|
      File.open(fmt_fn) do |f|
        fmt = TPEventFormat.parse(f)
        fmt && (@formats[fmt.name] = fmt)
      end
    end
  end

  def each
    @file.each_line do |line|
      (sample = TPSample.parse(line)) || next
      fmt = @formats[sample.type]
      fmt && fmt.convert(sample)
      yield sample
    end
  end
end

# usemem-1668   |   0.043 us    |  } /* swap_lock_page_or_retry */
# <...>-6436   |   0.065 us    |  swap_lock_page_or_retry();
#     TIME        CPU  TASK/PID         DURATION                  FUNCTION CALLS
#      |          |     |    |           |   |                     |   |   |   |
#    76.093718 |   6)   usemem-848   |   11.296 us   |  __do_page_fault();

# Funcgraph Duration sample
class FGSample
  RE_SAMPLE = /^\s*([^|]+)-(\d+)\s*\|\s*([0-9.]+)[us ]*\|[} \/*]*([a-zA-Z0-9_]+)/
  RE_SAMPLE2 = /^\s*([0-9.]+)\s+\|\s+(\d).\s+(.+)-(\d+)\s+\|\s+([0-9.]*).+\|[} \/*]*([a-zA-Z0-9_]+)/

  getter :cmd, :pid, :duration, :func

  def initialize(cmd : String, pid : Int32, duration : Float64, func : String)
    @cmd = cmd
    @pid = pid
    @duration = duration
    @func = func
  end

  def self.parse(str)
    case str
    when RE_SAMPLE
      new $1, $2.to_i, $3.to_f, $4
    when RE_SAMPLE2
      return if $5.to_f.zero?

      new $3, $4.to_i, $5.to_f, $6
    end
  end
end

class FGTrace
  def initialize(file : File)
    @file = file
  end

  def each
    @file.each_line do |line|
      (sample = FGSample.parse(line)) || next
      yield sample
    end
  end
end

# Func example:
#  swapper/0-1     [000] ....  90515845662: cpu_up <-smp_init

class FuncSample
  RE_SAMPLE = /^\s*([^\s]+)-(\d+)\s+\[(\d+)\]\s+([^\s]+)\s+([0-9.]+)\s*:\s*(.+)\s*<-(.+)\s*/

  getter :task, :pid, :cpu, :timestamp, :func, :callerfunc

  def initialize(task, pid, cpu, timestamp, func, callerfunc)
    @task = task
    @pid = pid
    @cpu = cpu
    @timestamp = timestamp
    @func = func
    @callerfunc = callerfunc
  end

  def self.parse(str)
    # taskname, pid, cpuID, timestamp, func, callerfunc
    FuncSample.new($1, $2.to_i, $3.to_i, $5.to_f, $6.strip, $7.strip) if str =~ RE_SAMPLE
  end
end

class FuncTrace
  def initialize(file)
    @file = file
  end

  def each
    block_given? || (return enum_for(__method__))
    @file.each_line do |line|
      (sample = FuncSample.parse(line)) || next
      yield sample
    end
  end
end
