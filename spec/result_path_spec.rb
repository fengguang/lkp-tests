require 'rspec'
require 'result'

describe ResultPath do
	describe "parse_result_root" do
		it "should succeed when result root is valid" do
			result_path = ResultPath.new

			expect(result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/2').to be true
			expect(result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/').to be true
			expect(result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27').to be true
		end

		it "should fail when commit id length is invalid" do
			result_path = ResultPath.new

			expect(result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a2').to be false
			expect(result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/').to be false
			expect(result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9').to be false
		end
	end
end
