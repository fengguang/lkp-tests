#!/usr/bin/env ruby

require 'erb'
require 'yaml'

LKP_SRC ||= File.dirname File.dirname __FILE__
require "#{LKP_SRC}/lib/hashugar.rb"

def expand_erb(template)
	return template unless template =~ /^%|<%|{{/
	template.gsub!(/{{(.*?)}}/m, '<%=\1%>')
	yaml = template.gsub(/^%.*$/, '').gsub(/<%.*?%>/m, '')
	job = YAML.load(yaml)
	context = Hashugar.new(job).instance_eval {binding}
	ERB.new(template, nil, '%').result(context)
end

