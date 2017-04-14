#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath(__FILE__)))

#         modprobe-2427  [008] ....   242.913825: vmalloc_alloc_area: start=0xffffc90001b07000, end=0xffffc90001b39000
#            bash-266   [001] ..s. 60321.215759: softirq_entry: vec=1 [action=TIMER]

class TPSample
  RES_ARG = /([^{\[(=,: \t\n]+)=([^}\])=,: \t\n]+)/
  RE_SAMPLE = /^\s*(.*)-(\d+)\s+\[(\d+)\]\s+\S+\s+([0-9.]+): ([^: ]+): (.*)$/

  attr_reader :cmd, :pid, :cpu, :timestamp, :type, :raw_data, :data

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

  class << self
    def parse(str)
      (md = self::RE_SAMPLE.match(str)) || return
      cmd = md[1]
      pid = md[2].to_i
      cpu = md[3].to_i
      timestamp = md[4].to_f
      type = md[5].intern
      raw_data = md[6]
      arg_pair_strs = raw_data.scan self::RES_ARG
      arg_pairs = arg_pair_strs.map do |k, v|
        [k.intern, v]
      end
      data = Hash[arg_pairs]
      new cmd, pid, cpu, timestamp, type, raw_data, data
    end
  end
end

class TPEventFormat
  RE_FMT = /^print fmt: "(.*)", /
  RE_NAME = /^name: ([^=,: \n]+)/
  RE_INT_FMT = /^(?:0[xX])?%.*[xud]$/

  attr_reader :name

  def initialize(name, args_desc)
    @name = name
    conv = args_desc.map do |arg, format|
      if format =~ RE_INT_FMT
        [arg, Object.method(:Integer)]
      else
        [arg, ->(x) { x }]
      end
    end
    @args_conv = Hash[conv]
  end

  def convert_data(data)
    data.each { |n, v| data[n] = @args_conv[n].call(v) }
  end

  def convert(sample)
    sample.conv_data(method(:convert_data))
  end

  class << self
    def parse(file)
      name = nil
      file.each_line do |line|
        name ||= self::RE_NAME.match line
        fmt = self::RE_FMT.match line
        if fmt
          arg_pair_strs = fmt[1].scan TPSample::RES_ARG
          arg_pairs = arg_pair_strs.map do |k, v|
            [k.intern, v]
          end
          args = Hash[arg_pairs]
        end
        name && fmt && (return new(name[1].strip.intern, args))
      end
    end
  end
end

class TPTrace
  def initialize(file, fmts_dir = nil)
    @file = file
    @formats = {}
    fmts_dir || return
    Dir.glob(File.join(fmts_dir, '*.fmt')).each do |fmt_fn|
      File.open(fmt_fn) do |f|
        fmt = TPEventFormat.parse(f)
        fmt && @formats[fmt.name] = fmt
      end
    end
  end

  def each
    block_given? || (return enum_for(__method__))

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

# Funcgraph Duration sample
class FGSample
  RE_SAMPLE = /^\s*(.+)-(\d+)\s*\|\s*([0-9.]+)[us ]*\|[} \/*]*([a-zA-Z0-9_]+)/

  attr_reader :cmd, :pid, :duration, :func

  def initialize(cmd, pid, duration, func)
    @cmd = cmd
    @pid = pid
    @duration = duration
    @func = func
  end

  class << self
    def parse(str)
      (md = self::RE_SAMPLE.match(str)) || return
      new md[1], md[2].to_i, md[3].to_f, md[4].intern
    end
  end
end

class FGTrace
  def initialize(file)
    @file = file
  end

  def each
    block_given? || (return enum_for(__method__))

    @file.each_line do |line|
      (sample = FGSample.parse(line)) || next
      yield sample
    end
  end
end
