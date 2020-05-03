#!/usr/bin/env crystal

RESULT_ROOT = ENV["RESULT_ROOT"]

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath(PROGRAM_NAME)))
require "../../lib/ftrace"
require "../../lib/common"
require "../../lib/statistics"
require "../../lib/data_analysis"
require "../../lib/ftrace_funcgraph"

# Analyze these samples to get how many times irq/softirq happened
# and how long they take
class IrqAnalysis
  def initialize(sample_array)
    @sample_array = sample_array
    @last = nil
    @irq = {}
    @softirq = {}
    @irq_nr = @irq_time = @softirq_nr = @softirq_time = 0
  end

  getter :irq_nr, :irq_time, :softirq_nr, :softirq_time

  def produce_result
    @irq.each do |_, array|
      @irq_nr += array.size
      @irq_time += array.sum
    end
    @softirq.each do |_, array|
      @softirq_nr += array.size
      @softirq_time += array.sum
    end

    return if @irq_nr.zero? && @softirq_nr.zero?

    puts "irq_nr: #{@irq_nr}"
    puts "softirq_nr: #{@softirq_nr}"
    puts "irq_time: #{@irq_time}"
    puts "softirq_time: #{@softirq_time}"
  end

  def mismatch(s1, s2)
    return true if s1.pid != s2.pid

    key = "irq"
    key = "vec" if s1.type == :softirq_entry
    return true if s1.data[key] != s2.data[key]

    false
  end

  def process(s1, s2)
    return if mismatch(s1, s2)

    t = (s2.timestamp * 1_000_000).to_i - (s1.timestamp * 1_000_000).to_i
    if s1.type == :softirq_entry
      vec_nr = s1.data["vec"]
      @softirq[vec_nr] ||= []
      @softirq[vec_nr] << t
    else
      irq_nr = s1.data["irq"]
      @irq[irq_nr] ||= []
      @irq[irq_nr] << t
    end
  end

  def analyze
    @sample_array.each do |sample|
      if @last
        process @last, sample if sample.type == :softirq_exit || sample.type == :irq_handler_exit
        @last = nil
      elsif sample.type == :softirq_entry || sample.type == :irq_handler_entry
        @last = sample
      end
    end
    produce_result
  end
end

def extract_ftrace(fn)
  fmts_dir = "#{RESULT_ROOT}/ftrace_events"
  file = zopen(fn)
  trace = TPTrace.new file, fmts_dir

  samples = {}
  # interrupt handler will not be migrated so to simply entry/exit
  # pair match, sort these samples according to CPU number
  trace.each do |sample|
    samples[sample.cpu] ||= []
    samples[sample.cpu] << sample
  end

  samples_array = []
  # then we put these sorted lines into a global array
  samples.each do |_, array|
    array.each do |sample|
      samples_array << sample
    end
  end
  samples_array
end

fn = "#{RESULT_ROOT}/ftrace.data.xz"
unless File.exist?(fn)
  log_error "log file #{fn} does not exist"
  exit
end

irq_analysis = IrqAnalysis.new(extract_ftrace(fn))
irq_analysis.analyze

# funcgraph
analyze
