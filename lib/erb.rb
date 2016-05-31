#!/usr/bin/env ruby

require 'erb'
require 'yaml'

LKP_SRC ||= File.dirname File.dirname __FILE__
require "#{LKP_SRC}/lib/hashugar.rb"

def expand_erb(template)
	return template unless template =~ /^%|<%|{{/

	# support {{ expression }}
	template.gsub!(/{{(.*?)}}/m, '<%=\1%>')

	# Support references to variables (with real values) defined in the same job.
	#
	# This follows the KISS principle: just good enough to meet simple requirements.
	# It's anti-intuitive and hence discouraged to write complex macro/templates
	# in job YAML anyway.
	#
	# The implementation is not clean in several ways,
	#
	# - the ERB code reduction gsubs do not handle ^%% <%% escaped tags
	#   yet to see who will use such strings in YAML
	#
	# - the ERB code reduced YAML may be an invalid YAML
	#   YAML.load will fail and you are probably writing too complex templates
	#
	yaml = template.gsub(/^%.*$/, '').gsub(/<%.*?%>/m, '')
	job = YAML.load(yaml)
	context = Hashugar.new(job).instance_eval {binding}

	ERB.new(template, nil, '%').result(context)
end

