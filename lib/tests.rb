LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'set'

def all_tests
  tests = Dir["#{LKP_SRC}/{tests,daemon}/**/*"].map { |d| File.basename(d) }
  tests.delete 'wrapper'
  tests.sort!
  tests
end

def cached_all_tests
  $__all_tests ||= all_tests.freeze
end

def all_tests_set
  $__all_tests_set ||= Set.new(cached_all_tests).freeze
end
