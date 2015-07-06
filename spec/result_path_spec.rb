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

		describe "project_info" do
			it "should handle default path" do
				result_path = ResultPath.new

				result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/2'

				result_path.each_commit do |project, commit_axis|
					expect(project).to eq 'linux'
					expect(commit_axis).to eq 'commit'
				end
			end

			it "should handle dpdk path" do
				result_path = ResultPath.new

				result_path.parse_result_root '/result/build-dpdk/x86_64-native-linuxapp-gcc/gcc/60c5c5692107abf4157d48493aa2dec01f6b97cc'

				result_path.each_commit do |project, commit_axis|
					expect(project).to eq 'dpdk'
					expect(commit_axis).to eq 'dpdk_commit'
				end
			end
		end

		describe "commit_axis" do
			it "should handle dpdk path" do
				result_path = ResultPath.new

				result_path.parse_result_root '/result/build-dpdk/x86_64-native-linuxapp-gcc/gcc/60c5c5692107abf4157d48493aa2dec01f6b97cc'
				expect(result_path.commit_axis).to eq 'dpdk_commit'
			end

			it "should handle linux path" do
				result_path = ResultPath.new

				result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/2'
				expect(result_path.commit_axis).to eq 'commit'
			end
		end

		describe "maxis_keys" do
			it "should handle dpdk path" do
				expect(ResultPath.maxis_keys('build-dpdk').size).to eq 3
			end
		end
	end
end
