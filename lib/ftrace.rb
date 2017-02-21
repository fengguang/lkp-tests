#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']

#         modprobe-2427  [008] ....   242.913825: vmalloc_alloc_area: start=0xffffc90001b07000, end=0xffffc90001b39000

class TPSample
  RES_ARG = "[^=,: \n]+=[^=,: \n]+".freeze
  RE_SAMPLE = Regexp.new('^\s*(.*)-(\d+)\s+\[\d+\]\s+\S+\s+([0-9.]+): ([^: ]+): ' + "((?:#{RES_ARG}, )*#{RES_ARG})$")

  attr_reader :cmd, :pid, :timestamp, :type, :data

  def initialize(cmd, pid, timestamp, type, data)
    @cmd = cmd
    @pid = pid
    @timestamp = timestamp
    @type = type
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
      timestamp = md[3].to_f
      type = md[4].intern
      arg_pair_strs = md[5].split(', ')
      arg_pairs = arg_pair_strs.map do |ps|
        k, v = ps.split('=')
        [k.intern, v]
      end
      args = Hash[arg_pairs]
      new cmd, pid, timestamp, type, args
    end
  end
end

class TPEventFormat
  RES_ARG = "[^=,: \n]+=[^=,: \n]+".freeze
  RE_FMT = Regexp.new "^print fmt: \"((?:#{RES_ARG}, )*#{RES_ARG})\", "
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
          arg_pair_strs = fmt[1].split ', '
          arg_pairs = arg_pair_strs.map do |ps|
            k, v = ps.split('=')
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
