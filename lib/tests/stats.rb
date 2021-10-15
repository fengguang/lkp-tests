#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(File.dirname(File.realpath($PROGRAM_NAME))))

require "#{LKP_SRC}/lib/log"

module LKP
  class Stats
    def initialize
      @stats = {}
    end

    def key?(test_case)
      @stats.key? normalize(test_case)
    end

    def add(test_case, test_result)
      test_case = normalize(test_case)
      raise "#{test_case} has already existed" if key?(test_case)

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

    def method_missing(sym, *args, &block)
      @stats.send(sym, *args, &block)
    end

    # def exit(warn)
    #   log_warn warn if warn
    #   exit 1
    # end

    # def validate_duplication(hash, key)
    #   self.exit "#{key} has already existed" if hash.key? key
    # end

    private

    def normalize(test_case)
      test_case.strip
               .gsub(/[\s,"_\(\):]+/, '_')
               .gsub(/(^_+|_+$)/, '')
               .gsub(/_{2,}/, '_') # replace continuous _ to single _
    end
  end
end
