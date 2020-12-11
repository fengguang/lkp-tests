#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(File.dirname(File.realpath($PROGRAM_NAME))))

require "#{LKP_SRC}/lib/log"

module LKP
  class Stats
    def initialize
      @stats = {}
    end

    def add(test_case, test_result)
      test_case = test_case.strip
                           .gsub(/[\s,"_\(\):]+/, '_')
                           .gsub(/(^_|_$)/, '')
      raise "#{test_case} has already existed" if @stats.key? test_case

      test_result = test_result.strip.gsub(/\s+/, '_').downcase if test_result.instance_of? String

      @stats[test_case] = test_result
    end

    # mapping: { 'ok' => 'pass', 'not_ok' => 'fail' }
    def dump(mapping = {})
      @stats.each do |k, v|
        v = mapping[v] || v

        if v.instance_of? String
          puts "#{k}.#{v}: 1"
        else
          puts "#{k}: #{v}"
        end
      end
    end

    # def exit(warn)
    #   log_warn warn if warn
    #   exit 1
    # end

    # def validate_duplication(hash, key)
    #   self.exit "#{key} has already existed" if hash.key? key
    # end
  end
end
