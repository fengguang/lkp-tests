#!/usr/bin/env ruby

def get_dependency_packages(distro, script)
	file = "#{LKP_SRC}/distro/#{distro}/#{script}"
	return nil unless File.exist? file

	packages = []
	File.read(file).each_line do |line|
		line.sub(/#.*/, '')
		packages.concat line.split
	end

	return packages
end

