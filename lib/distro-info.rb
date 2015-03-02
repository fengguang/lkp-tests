#!/usr/bin/ruby

module LKP

	require "singleton"

	LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname File.realpath $PROGRAM_NAME)

	#
	# DistroInfo is singleton, and provide information to distribution information of local system
	# Include: system type, system name, system version, system arch
	# In the backend, it's invoking detect-system.sh to get environment infomation.
	# Example of properties on debian
	# 	p systemType => Linux
	# 	p systemName => Debian
	# 	p systemArch => x86_64
	# 	p systemVersion => jessie_sid
	#
	# @author: Yao Weiqi
	#
	class DistroInfo
		include Singleton
		attr_reader :systemType, :systemName, :systemArch, :systemVersion

		def initialize
			path_to_script = "#{LKP_SRC}/lib/detect-system.sh"

			@systemType = `. #{path_to_script} && echo $_system_type`
			@systemType.strip!
			@systemName = `. #{path_to_script} && echo $_system_name`
			@systemName.strip!
			@systemArch = `. #{path_to_script} && echo $_system_arch`
			@systemArch.strip!
			@systemVersion = `. #{path_to_script} && echo $_system_version`
			@systemVersion.strip!
		end
	end

end
