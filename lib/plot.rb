#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'gnuplot'
require "#{LKP_SRC}/lib/common"
require "#{LKP_SRC}/lib/property"
require "#{LKP_SRC}/lib/matrix"

PLOT_SIZE_X = 80
PLOT_SIZE_Y = 20
NR_PLOT = 1

module Gnuplot
  # fallback to v2.4.1 to avoid circular dependency and potential dead lock
  def self.open(persist = true)
    (cmd = Gnuplot.gnuplot(persist)) || raise('gnuplot not found')
    IO.popen(cmd, 'w') { |io| yield io }
  end
end

def mmplot(matrix1, matrix2, fields, title_prefix = nil)
  files = []
  Gnuplot.open do |gnuplot|
    fields.each do |field|
      Gnuplot::Plot.new(gnuplot) do |plot|
        ds1 = nil
        ds2 = nil

        # HEAD/BAD samples
        if matrix1[field]
          x = 1.upto(matrix1[field].size).collect { |v| v }
          Gnuplot::DataSet.new([x, matrix1[field]]) do |ds|
            ds.with = 'points pt 15 lt 0'
            ds.notitle
            ds1 = ds
          end
        end

        # BASE/GOOD samples
        if matrix2[field]
          xx = 1.upto(matrix2[field].size).collect { |v| v }
          Gnuplot::DataSet.new([xx, matrix2[field]]) do |ds|
            ds.with = 'linespoints pt -22 lt 0'
            ds.notitle
            ds2 = ds
          end
        end

        return nil if ds1.nil? && ds2.nil?

        normalized_field = field.tr('^a-zA-Z0-9_.:+=-', '_')
        if $opt_output_path
          plot.terminal 'png'
          file = "#{$opt_output_path}/#{normalized_field}.png"
          plot.output file
          files << file
        else
          plot.terminal "dumb nofeed size #{PLOT_SIZE_X},#{PLOT_SIZE_Y}"
        end

        plot.notitle # necessary for updating title

        title_prefix += ': ' if title_prefix
        plot.title format('%s%s', title_prefix, normalized_field)

        plot.noxtics
        plot.ytics 'nomirror'

        plot.data.push ds1 if ds1
        plot.data.push ds2 if ds2
      end
    end
  end
  files
end

def mmsplot(matrixes1, matrixes2, fields, title_prefix = nil)
  m1 = merge_matrixes(matrixes1)
  m2 = merge_matrixes(matrixes2)
  mmplot(m1, m2, fields, title_prefix)
end

class MatrixPlotterBase
  def initialize
    @pixel_size = [800, 480]
    @inch_size = [8, 4.8]
    @char_size = [PLOT_SIZE_X, PLOT_SIZE_Y]
  end

  include Property
  prop_with :pixel_size, :inch_size, :char_size

  def setup_output(plot, file_name)
    if file_name
      case file_name
      when /eps/
        plot.terminal format('eps noenhanced size %d,%d fontscale 1', @inch_size[0], @inch_size[1])
        file_name += '.eps' unless file_name.end_with? '.eps'
      when /\.plt$/
        plot.terminal 'qt noenhanced persist'
      else
        plot.terminal format('png noenhanced size %d,%d', @pixel_size[0], @pixel_size[1])
        file_name += '.png' unless file_name.end_with? '.png'
      end
      plot.output(file_name) unless file_name.end_with?('.plt')
    else
      plot.terminal format('dumb nofeed size %d,%d', @char_size[0], @char_size[1])
    end
  end

  def open_gnuplot(file_name = nil, &blk)
    if file_name && file_name.end_with?('.plt')
      File.open(file_name, 'w', &blk)
    else
      Gnuplot.open(&blk)
    end
  end
end

# Multiple Matrix Plotter
class MMatrixPlotter < MatrixPlotterBase
  def initialize
    super
    @lines = []
    @y_margin = 0.1
    @y_range = [nil, nil]
    @x_range = [nil, nil]
    @plot_type = 'multi_lines'
  end

  prop_with :output_file_name, :title
  prop_with :x_stat_key, :x_as_label, :xtics, :lines
  prop_with :y_margin, :y_range, :x_range
  prop_with :plot_type

  # shortcut for one line figure
  def set_line(matrix, y_stat_key, line_title = nil)
    @lines = [[matrix, y_stat_key, line_title]]
    self
  end

  def check_line(values)
    values && (values.max != 0 || values.min != 0)
  end

  def check_lines
    @lines.each do |matrix, y_stat_key, _line_title|
      return true if check_line(matrix[y_stat_key])
    end
    false
  end

  def plot_multi_lines
    return unless check_lines

    open_gnuplot(@output_file_name) do |gp|
      Gnuplot::Plot.new(gp) do |p|
        setup_output(p, @output_file_name)
        p.title @title if @title
        p.ytics 'nomirror'

        x_start = @x_range[0] || 0
        x_len = @x_range[1] ? @x_range[1] - x_start : nil
        y_min, y_max = nil
        @lines.each do |matrix, y_stat_key, line_title|
          values_all = matrix[y_stat_key]
          values = values_all && values_all[x_start, x_len || values_all.length]
          next unless check_line(values)

          max = values.max
          min = values.min
          y_min = y_min ? [min, y_min].min : min
          y_max = y_max ? [max, y_max].max : max

          if @x_stat_key
            xs_all = matrix[@x_stat_key]
            xs = xs_all[x_start, x_len || xs_all.length]
            data = [xs, values]
          else
            data = [values]
            p.noxtics unless @xtics
          end
          p.data << Gnuplot::DataSet.new(data) do |ds|
            ds.with = if @output_file_name
                        'linespoints pt 5'
                      else
                        'linespoints pt 15 lt 0'
                      end
            ds.using = '2:xticlabels(1)' if @x_as_label
            if line_title
              ds.title = line_title
            else
              ds.notitle
            end
          end
        end
        y_size = y_max - y_min
        y_size = y_min if y_size.zero?
        y_min -= y_size * @y_margin
        y_max += y_size * @y_margin
        y_min = @y_range[0] || y_min
        y_max = @y_range[1] || y_max
        p.yrange "[#{y_min}:#{y_max}]"
      end
    end
  end

  def plot_error_bars
    return unless check_lines

    Gnuplot.open do |gp|
      Gnuplot::Plot.new(gp) do |p|
        setup_output(p, @output_file_name)
        p.title "'#{@title}' noenhanced font ',24'" if @title
        p.ytics 'nomirror font ",24"'
        p.y2tics 'nomirror font ",24"'

        y_max = nil
        y_min = nil
        x_stat = []
        y_stat = []
        y_stat_max = []
        y_stat_min = []
        z_stat = []
        @lines.each do |matrix, y_stat_key, _line_title|
          values = matrix[y_stat_key]
          next unless check_line(values)

          values.map!(&:to_f)

          case y_stat_key
          when /min$/
            y_stat_min = values
            x_stat = matrix[@x_stat_key]
          when /max$/
            y_stat_max = values
          end

          max = values.max
          min = values.min
          y_min = y_min ? [min, y_min].min : min
          y_max = y_max ? [max, y_max].max : max
        end

        y_stat = (1..y_stat_max.size).map { |i| (y_stat_max[i - 1] + y_stat_min[i - 1]) / 2 }
        y_base = if y_stat.size > 2
                   y_stat[-2]
                 else
                   y_stat[0]
                 end

        y_stat.map! { |v| (v / y_base * 100).round(2) }
        y_stat_max.map! { |v| (v / y_base * 100).round(2) }
        if y_stat.size == y_stat_max.size
          z_stat = (1..y_stat.size).map { |i| (y_stat_max[i - 1] - y_stat[i - 1]).round(2) }
        end

        xtics_stat = x_stat.map.with_index { |x, i| format('"%s" %d', x, i + 1) }.join(', ')
        p.xtics "(#{xtics_stat}) font ',24' offset 0,-0.5"
        x_stat = (1..x_stat.size).to_a
        p.xrange "[0.9:#{x_stat.size + 0.1}]"

        ref_line_stat = Array.new(x_stat.size, 100)
        p.data = [
          Gnuplot::DataSet.new([x_stat, y_stat, z_stat]) do |ds|
            ds.with = 'errorb'
            ds.notitle
          end,
          Gnuplot::DataSet.new([x_stat, y_stat]) do |ds|
            ds.with = 'linespoints'
            ds.notitle
          end,
          Gnuplot::DataSet.new([x_stat, ref_line_stat]) do |ds|
            ds.with = "lines lt '-'"
            ds.notitle
          end
        ]
        y_max = (y_max / y_base * 100 + 5).round
        y_min = (y_min / y_base * 100 - 5).round
        p.yrange "[#{y_min}:#{y_max}]"
        p.y2range "[#{y_min}:#{y_max}]"
      end
    end
  end

  def plot
    method_name = "plot_#{@plot_type}"
    public_send(method_name) if respond_to? method_name
  end
end

class MatrixPlotter < MatrixPlotterBase
  def initialize
    super
    @nr_plot = NR_PLOT
  end

  prop_with :output_prefix, :title_prefix, :nr_plot
  prop_with :matrix, :x_stat_key, :y_stat_keys

  def plot
    np = 0
    Gnuplot.open do |gp|
      @y_stat_keys.each do |field, var|
        values = @matrix[field]
        next if values.max == values.min

        normalized_field = field.tr('^a-zA-Z0-9_.:+=-', '_')
        field_title = normalized_field
        Gnuplot::Plot.new(gp) do |p|
          if @output_prefix
            file = @output_prefix + normalized_field
            setup_output p, file
          else
            if (np % @nr_plot).zero?
              p.terminal format('dumb nofeed size %d,%d', @char_size[0], @char_size[1])
              p.multiplot "layout 1,#{@nr_plot}"
            end
            np += 1
          end

          plot_unit = MatrixPlotter.plot_unit
          unit_size = MatrixPlotter.unit_size
          if plot_unit[field]
            p.ylabel plot_unit[field]
            unit_scale = unit_size[plot_unit[field]]
            values = values.map { |v| v / unit_scale.to_f }
          end

          p.notitle # necessary for updating title
          if var
            p.title format("'%s%s (var %.2f)'", @title_prefix, field_title, var)
          else
            p.title format("'%s%s'", @title_prefix, field_title)
          end

          if @x_stat_key
            data = [@matrix[@x_stat_key], values]
          else
            data = [values]
            p.noxtics
          end
          p.ytics 'nomirror'

          p.data << Gnuplot::DataSet.new(data) do |ds|
            ds.with = if @output_prefix
                        'linespoints pt 5'
                      else
                        'linespoints pt 15 lt 0'
                      end
            ds.notitle
          end
        end
      end
    end
  end

  def call(matrix_in = nil, y_stat_keys_in = nil, x_stat_key_in = nil)
    with_matrix(matrix_in || matrix) do
      with_x_stat_key(x_stat_key_in || x_stat_key) do
        with_y_stat_keys(y_stat_keys_in || y_stat_keys) do
          plot
        end
      end
    end
  end
end

class << MatrixPlotter
  def plot_unit
    @plot_unit ||= load_yaml LKP_SRC + '/etc/plot-unit.yaml'
  end

  def unit_size
    @unit_size = load_yaml LKP_SRC + '/etc/unit-size.yaml'
  end
end

def mplot(matrix, stats, x_stat_key = nil)
  p = MatrixPlotter.new
  p.set_output_prefix ensure_dir($opt_output_path) if $opt_output_path
  p.call(matrix, stats, x_stat_key)
end
