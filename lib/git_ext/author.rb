#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(File.dirname(File.realpath(__FILE__))))

require 'git'

module Git
  class Author
    def formatted_name
      "#{@name} <#{@email}>"
    end
  end
end
