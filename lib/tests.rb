
require 'set'

def __calc_all_tests
	tests = Dir["#{LKP_SRC}/tests/**/*"].map { |d| File.basename (d) }
	tests.sort!
end

AllTests = __calc_all_tests.freeze
AllTestsSet = Set.new(AllTests).freeze
