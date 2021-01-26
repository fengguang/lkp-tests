#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

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
end
