#!/usr/bin/env ruby

LKP_SRC ||= ENV["LKP_SRC"]
LKP_CORE_SRC ||= ENV['LKP_CORE_SRC'] || LKP_SRC

require 'yaml'
require "#{LKP_SRC}/lib/assert"

class RepoSpec
	ROOT_DIR = LKP_SRC + '/repo'

	def initialize(name)
		file = Dir[File.join(ROOT_DIR, '*', name)].first
		assert file, "can't find #{name} spec under #{ROOT_DIR}"

		@spec = YAML.load_file(file)
		assert @spec, "invalid spec #{file}"
	end

	def [](key)
		@spec[key]
	end

end
