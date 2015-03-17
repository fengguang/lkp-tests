#!/usr/bin/ruby

LKP_SRC ||= ENV['LKP_SRC']

require "gnuplot"
require "#{LKP_SRC}/lib/matrix.rb"

PLOT_SIZE_X = 80
PLOT_SIZE_Y = 20
NR_PLOT = 1

def mmplot(matrix1, matrix2, fields, title_prefix=nil)
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
end

def mmsplot(matrixes1, matrixes2, fields, title_prefix=nil)
	m1 = merge_matrixes(matrixes1)
	m2 = merge_matrixes(matrixes2)
	mmplot(m1, m2, fields, title_prefix)
end

def mplot(matrix, stats)
	nr_plot = 0
	unless $plot_unit
		$plot_unit = load_yaml LKP_SRC + '/etc/plot-unit.yaml'
		$unit_size = load_yaml LKP_SRC + '/etc/unit-size.yaml'
	end
	Gnuplot.open do |gp|
	stats.each do |field, var|
	values = matrix[field]
	next if values.max == values.min
	Gnuplot::Plot.new( gp ) do |plot|
	if $opt_output_path
		file = $opt_output_path + '/' + field.tr('^a-zA-Z0-9_.:+=-', '_')
		case $opt_output_path
		when /eps/
			plot.terminal "eps size 8,4.8 fontscale 1"
			file += ".eps"
		else
			plot.terminal "png size 800,480"
			file += ".png"
		end
		plot.output file
	else
		if nr_plot % NR_PLOT == 0
			plot.terminal "dumb nofeed size #{PLOT_SIZE_X},#{PLOT_SIZE_Y}"
			plot.multiplot "layout 1,#{NR_PLOT}"
		end
		nr_plot += 1
	end

	if $plot_unit[field]
		plot.ylabel $plot_unit[field]
		unit_scale = $unit_size[$plot_unit[field]]
		values = values.map { |v| v / unit_scale.to_f }
	end

	plot.notitle # necessary for updating title
	if var
		plot.title format("%s (var %.2f)", field, var)
	else
		plot.title format("%s", field)
	end

	plot.noxtics
	plot.ytics 'nomirror'

	plot.data << Gnuplot::DataSet.new( [values] ) do |ds|
		if $opt_output_path
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
