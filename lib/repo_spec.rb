#!/usr/bin/env ruby

LKP_SRC ||= ENV["LKP_SRC"]

require 'yaml'
require "#{LKP_SRC}/lib/assert"
require "#{LKP_SRC}/lib/lkp_git"

class RepoSpec
  ROOT_DIR = LKP_SRC + '/repo'

  def initialize(name)
    $remotes ||= load_remotes

    @name = name
    @spec = $remotes[name]

    assert @spec, "can't find repo spec #{@name}"
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
