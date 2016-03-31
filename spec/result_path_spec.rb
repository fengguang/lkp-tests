require 'spec_helper'
require "#{LKP_SRC}/lib/result"

describe ResultPath do
	describe "parse_result_root" do
		it "should succeed when result root is valid" do
			result_path = ResultPath.new

			expect(result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/2').to be true
			expect(result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/').to be true
			expect(result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27').to be true
			expect(result_path['testcase']).to eq 'aim7'
			expect(result_path['path_params']).to eq 'performance-2000-fork_test'
			expect(result_path['tbox_group']).to eq 'brickland3'
			expect(result_path['rootfs']).to eq 'debian-x86_64-2015-02-07.cgz'
			expect(result_path['kconfig']).to eq 'x86_64-rhel'
			expect(result_path['compiler']).to eq 'gcc-4.9'
			expect(result_path['commit']).to eq '0f57d86787d8b1076ea8f9cbdddda2a46d534a27'
			expect(result_path.parse_result_root '/result/build-dpdk/x86_64-native-linuxapp-gcc/gcc/60c5c5692107abf4157d48493aa2dec01f6b97cc/0').to be true
			expect(result_path.parse_result_root '/result/build-dpdk/x86_64-native-linuxapp-gcc/gcc/60c5c5692107abf4157d48493aa2dec01f6b97cc/').to be true
			expect(result_path.parse_result_root '/result/build-dpdk/x86_64-native-linuxapp-gcc/gcc/60c5c5692107abf4157d48493aa2dec01f6b97cc').to be true
			expect(result_path['testcase']).to eq 'build-dpdk'
			expect(result_path['dpdk_config']).to eq 'x86_64-native-linuxapp-gcc'
			expect(result_path['dpdk_compiler']).to eq 'gcc'
			expect(result_path['dpdk_commit']).to eq '60c5c5692107abf4157d48493aa2dec01f6b97cc'
			expect(result_path.parse_result_root '/result/lkp-a03/hwinfo/performance-1/debian-x86_64.cgz/x86_64-rhel/0df1f2487d2f0d04703f142813d53615d62a1da4/').to be true
			expect(result_path.parse_result_root '/result/lkp-a03/hwinfo/performance-1/debian-x86_64.cgz/x86_64-rhel/0df1f2487d2f0d04703f142813d53615d62a1da4').to be true
			expect(result_path['testcase']).to eq 'hwinfo'
			expect(result_path['path_params']).to eq 'performance-1'
			expect(result_path['tbox_group']).to eq 'lkp-a03'
			expect(result_path['rootfs']).to eq 'debian-x86_64.cgz'
			expect(result_path['kconfig']).to eq 'x86_64-rhel'
			expect(result_path['compiler']).to eq 'gcc-4.9'
			expect(result_path['commit']).to eq '0df1f2487d2f0d04703f142813d53615d62a1da4'
		end

		it "should fail when commit id length is invalid" do
			result_path = ResultPath.new

			expect(result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a2').to be false
			expect(result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/').to be false
			expect(result_path.parse_result_root '/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9').to be false
			expect(result_path.parse_result_root '/result/build-dpdk/x86_64-native-linuxapp-gcc/gcc/60c5c5692107abf4157d48493aa2dec01f6b97c').to be false
			expect(result_path.parse_result_root '/result/build-dpdk/x86_64-native-linuxapp-gcc/gcc/').to be false
			expect(result_path.parse_result_root '/result/build-dpdk/x86_64-native-linuxapp-gcc/gcc').to be false
			expect(result_path.parse_result_root '/result/lkp-a03/hwinfo/performance-1/debian-x86_64.cgz/x86_64-rhel/0df1f2487d2f0d04703f142813d53615d62a1da').to be false
			expect(result_path.parse_result_root '/result/lkp-a03/hwinfo/performance-1/debian-x86_64.cgz/x86_64-rhel/').to be false
			expect(result_path.parse_result_root '/result/lkp-a03/hwinfo/performance-1/debian-x86_64.cgz/x86_64-rhel').to be false
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

		describe "each_commit" do
			it "should return enumerator" do
				result_path = ResultPath.new
				result_path.parse_result_root '/result/build-dpdk/x86_64-native-linuxapp-gcc/gcc/60c5c5692107abf4157d48493aa2dec01f6b97cc'

				expect(result_path.each_commit.any? {|project| project == 'dpdk'}).to be true
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
