#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']

require 'yaml'

def get_dependency_packages(distro, script)
	base_file = "#{LKP_SRC}/distro/debian/#{script}"
	return [] unless File.exist? base_file

	generic_packages = []
	File.read(base_file).each_line do |line|
                line.sub(/#.*/, '')
                generic_packages.concat line.split
        end

	# generic_packages based on debian
	return generic_packages if distro == 'debian'

	distro_file = "#{LKP_SRC}/distro/adaptation/#{distro}"
	distro_packages = YAML.load_file(distro_file)
	packages = []
	generic_packages.each_with_index { |pkg_name, index|
		if distro_packages.include? pkg_name
			packages.push distro_packages[pkg_name]
		else
			packages.push generic_packages[index]
		end
	}

	return packages.flatten.compact
end
