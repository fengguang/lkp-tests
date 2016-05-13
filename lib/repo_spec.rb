#!/usr/bin/env ruby

LKP_SRC ||= ENV["LKP_SRC"]
LKP_CORE_SRC ||= ENV['LKP_CORE_SRC'] || LKP_SRC

require 'yaml'
require "#{LKP_SRC}/lib/assert"

class RepoSpec
	ROOT_DIR = LKP_SRC + '/repo'

	def initialize(name)
		@name = name

		spec_path = Dir[File.join(ROOT_DIR, '*', @name)].first
		assert spec_path, "can't find #{@name} spec under #{ROOT_DIR}"

		@spec = YAML.load_file(spec_path)
		assert @spec, "invalid spec #{spec_path}"

		defaults_spec_path = File.join(File.dirname(spec_path), 'DEFAULTS')
		if File.exist? defaults_spec_path
			defaults_spec = YAML.load_file(defaults_spec_path)
			assert defaults_spec, "invalid defaults spec #{defaults_spec_path}"

			@spec = defaults_spec.merge(@spec)
		end
	end

	def [](key)
		@spec[key]
	end

	def internal?
		@name =~ /^internal-/
	end

	class << self
		def url_to_remote(url)
			unless @url_remotes
				names = Dir[File.join(ROOT_DIR, '*', '*')].map {|file| File.basename file}.reject {|name| name == 'DEFAULTS'}
				@url_remotes = Hash[names.map {|name| [self.new(name)['url'], name]}]
			end

			@url_remotes[url]
		end

	end
end
