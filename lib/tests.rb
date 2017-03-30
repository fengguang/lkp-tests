LKP_SRC ||= ENV['LKP_SRC']

require 'set'

def get_all_tests
  tests = Dir["#{LKP_SRC}/{tests,daemon}/**/*"].map { |d| File.basename (d) }
  tests.delete 'wrapper'
  tests.sort!
  tests
end

def all_tests
  $__all_tests ||= get_all_tests.freeze
end

def all_tests_set
  $__all_tests_set ||= Set.new(all_tests).freeze
end
