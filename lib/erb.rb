#!/usr/bin/env ruby

require 'erb'
require 'yaml'
require 'ostruct'

def expand_erb(template)
	return template unless template =~ /^%|<%|{{/
	template.gsub!(/{{(.*?)}}/m, '<%=\1%>')
	yaml = template.gsub(/^%.*$/, '').gsub(/<%.*?%>/m, '')
	job = YAML.load(yaml)
	context = OpenStruct.new(job).instance_eval {binding}
	ERB.new(template, nil, '%').result(context)
end

