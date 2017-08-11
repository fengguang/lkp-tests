#!/usr/bin/env ruby
LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath(__FILE__)))

module LKP
  require "singleton"

  #
  # DistroInfo is singleton, and provide information to distribution information of local system
  # Include: system name, system version, system arch
  # In the backend, it's invoking detect-system.sh to get environment information.
  # Example of properties on debian
  #   p systemName => Debian
  # p systemNameL => debian (lowercase)
  #   p systemArch => x86_64
  #   p systemVersion => jessie_sid
  #
  # @author: Yao Weiqi
  #
  class DistroInfo
    include Singleton
    attr_reader :systemName, :systemNameL, :systemVersion, :systemArch

    def initialize(rootfs = '/')
      path_to_script = "#{LKP_SRC}/lib/detect-system.sh"

      @systemName, @systemNameL, @systemVersion, @systemArch = %x[
        . #{path_to_script}
        detect_system #{rootfs}
        echo $_system_name
        echo $_system_name_lowercase
        echo $_system_version
        echo $_system_arch
      ].split
    end
  end
end
