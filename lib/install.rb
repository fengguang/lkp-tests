#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']

require 'yaml'

def adapt_packages(distro, generic_packages)
  distro_file = "#{LKP_SRC}/distro/adaptation/#{distro}"
  return generic_packages unless File.exist? distro_file

  distro_packages = YAML.load_file(distro_file)

  generic_packages.map do |pkg|
    if distro_packages.include? pkg
      distro_packages[pkg].to_s.split
    else
      pkg
    end
  end
end

def get_dependency_packages(distro, script)
  base_file = "#{LKP_SRC}/distro/depends/#{script}"
  return [] unless File.exist? base_file

  generic_packages = []
  File.read(base_file).each_line do |line|
                line.sub(/#.*/, '')
                generic_packages.concat line.split
  end

  packages = adapt_packages(distro, generic_packages)

  packages.flatten.compact.uniq
end
