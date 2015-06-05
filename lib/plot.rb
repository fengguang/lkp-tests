#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']

require "gnuplot"
require "#{LKP_SRC}/lib/common.rb"
require "#{LKP_SRC}/lib/property.rb"
require "#{LKP_SRC}/lib/matrix.rb"

PLOT_SIZE_X = 80
PLOT_SIZE_Y = 20
NR_PLOT = 1

def mmplot(matrix1, matrix2, fields, title_prefix=nil)
	files = []
	Gnuplot.open do |gnuplot|
	fields.each do |field|
	Gnuplot::Plot.new(gnuplot) do |plot|

	ds1 = nil
	ds2 = nil

	# HEAD/BAD samples
	if matrix1[field]
		x = 1.upto(matrix1[field].size).collect { |v| v }
		Gnuplot::DataSet.new( [x, matrix1[field]] ) { |ds|
			ds.with = "points pt 15 lt 0"
			ds.notitle
			ds1 = ds
		}
	end

	# BASE/GOOD samples
	if matrix2[field]
		xx = 1.upto(matrix2[field].size).collect { |v| v }
		Gnuplot::DataSet.new( [xx, matrix2[field]] ) { |ds|
			ds.with = "linespoints pt -22 lt 0"
			ds.notitle
			ds2 = ds
		}
	end

	return if ds1 == nil and ds2 == nil

	if $opt_output_path
		plot.terminal "png"
		file = field.tr('^a-zA-Z0-9_.:+=-', '_')
		file = "#{$opt_output_path}/#{file}.png"
		plot.output "#{file}"
		files << file
	else
		plot.terminal "dumb nofeed size #{PLOT_SIZE_X},#{PLOT_SIZE_Y}"
	end

	plot.notitle # necessary for updating title

	title_prefix += ": " if title_prefix
	plot.title  format("%s%s", title_prefix, field)

	plot.noxtics
	plot.ytics 'nomirror'

	plot.data.push ds1 if ds1
	plot.data.push ds2 if ds2

	end
	end
	end
	files
end

def mmsplot(matrixes1, matrixes2, fields, title_prefix=nil)
	m1 = merge_matrixes(matrixes1)
	m2 = merge_matrixes(matrixes2)
	mmplot(m1, m2, fields, title_prefix)
end

class MatrixPlotter
	def initialize
		@pixel_size = [800, 480]
		@inch_size = [8, 4.8]
		@char_size = [PLOT_SIZE_X, PLOT_SIZE_Y]
		@nr_plot = NR_PLOT

		@plot_unit = load_yaml LKP_SRC + '/etc/plot-unit.yaml'
		@unit_size = load_yaml LKP_SRC + '/etc/unit-size.yaml'
	end

	include Property
	prop_with :output_prefix, :title_prefix
	prop_with :pixel_size, :inch_size, :char_size, :nr_plot
	prop_with :matrix, :x_stat_key, :y_stat_keys

	def plot
		np = 0
		Gnuplot.open do |gp|
		@y_stat_keys.each do |field, var|
		values = @matrix[field]
		next if values.max == values.min
		Gnuplot::Plot.new( gp ) do |p|
		if @output_prefix
			file = @output_prefix + field.tr('^a-zA-Z0-9_.:+=-', '_')
			case @output_prefix
			when /eps/
				p.terminal "eps size %d,%d fontscale 1" % @inch_size
				file += ".eps"
			else
				p.terminal "png size %d,%d" % @pixel_size
				file += ".png"
			end
			p.output file
		else
			if np % @nr_plot == 0
				p.terminal "dumb nofeed size %d,%d" % @char_size
				p.multiplot "layout 1,#{@nr_plot}"
			end
			np += 1
		end

		if @plot_unit[field]
			p.ylabel @plot_unit[field]
			unit_scale = @unit_size[@plot_unit[field]]
			values = values.map { |v| v / unit_scale.to_f }
		end

		p.notitle # necessary for updating title
		if var
			p.title format("%s%s (var %.2f)", @title_prefix, field, var)
		else
			p.title format("%s%s", @title_prefix, field)
		end

		if @x_stat_key
			data = [@matrix[@x_stat_key], values]
		else
			data = [values]
			p.noxtics
		end
		p.ytics 'nomirror'

		p.data << Gnuplot::DataSet.new(data) do |ds|
			if @output_prefix
				ds.with = "linespoints pt 5"
			else
				ds.with = "linespoints pt 15 lt 0"
			end
			ds.notitle
		end
		end
		end
		end
	end

	def call(matrix_in = nil, y_stat_keys_in = nil, x_stat_key_in = nil)
		with_matrix(matrix_in || matrix) {
			with_x_stat_key(x_stat_key_in || x_stat_key) {
				with_y_stat_keys(y_stat_keys_in || y_stat_keys) {
					plot
				}
			}
		}
	end
end

def mplot(matrix, stats, x_stat_key = nil)
	p = MatrixPlotter.new
	if $opt_output_path
		p.set_output_prefix ensure_dir($opt_output_path)
	end
	p.(matrix, stats, x_stat_key)
end
