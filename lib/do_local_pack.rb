#!/usr/bin/env ruby
# frozen_string_literal: true

require "#{ENV['LKP_SRC']}/lib/local_pack"

def do_local_pack
  pkg_repos = [ENV['LKP_SRC']]
  pkg_repos.insert(-1, ENV['LKP_SRC2']) if ENV['LKP_SRC2']

  pkg_repos.each do |repo|
    do_package = PackChange.new(repo, true)
    do_package.pack_source
  end
end
