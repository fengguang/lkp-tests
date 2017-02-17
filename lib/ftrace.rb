#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']

class TPSample
  RES_ARG = "[^=,: \n]+=[^=,: \n]+".freeze
  RE_SAMPLE = Regexp.new ": ([^: ]+): ((?:#{RES_ARG}, )*#{RES_ARG})$"

  attr_reader :type, :data

  def initialize(type, data)
    @type = type
    @data = data
  end

  def [](key)
    @data[key]
  end

  class << self
    def parse(str)
      (md = self::RE_SAMPLE.match(str)) || return
      type = md[1].intern
      arg_pair_strs = md[2].split(', ')
      arg_pairs = arg_pair_strs.map do |ps|
        k, v = ps.split('=')
        [k.intern, v]
      end
      args = Hash[arg_pairs]
      new type, args
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

  def convert(sample)
    ndata = sample.data.map { |n, v| [n, @args_conv[n].call(v)] }
    TPSample.new(sample.type, Hash[ndata])
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
      csample =
        if fmt
          fmt.convert(sample)
        else
          sample
        end
      yield csample
    end
  end
end
