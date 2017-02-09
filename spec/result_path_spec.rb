require 'spec_helper'
require "#{LKP_SRC}/lib/result"

describe ResultPath do
  describe '#parse_result_root' do
    context 'when given valid result root' do
      it 'succeeds' do
        result_path = described_class.new

        expect(result_path.parse_result_root('/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/2')).to be true
        expect(result_path.parse_result_root('/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/')).to be true
        expect(result_path.parse_result_root('/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27')).to be true
        expect(result_path['testcase']).to eq 'aim7'
        expect(result_path['path_params']).to eq 'performance-2000-fork_test'
        expect(result_path['tbox_group']).to eq 'brickland3'
        expect(result_path['rootfs']).to eq 'debian-x86_64-2015-02-07.cgz'
        expect(result_path['kconfig']).to eq 'x86_64-rhel'
        expect(result_path['compiler']).to eq 'gcc-4.9'
        expect(result_path['commit']).to eq '0f57d86787d8b1076ea8f9cbdddda2a46d534a27'

        expect(result_path.parse_result_root('/result/build-qemu/x86_64-softmmu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92/2')).to be true
        expect(result_path.parse_result_root('/result/build-qemu/x86_64-softmmu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92/')).to be true
        expect(result_path.parse_result_root('/result/build-qemu/x86_64-softmmu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92')).to be true
        expect(result_path['testcase']).to eq 'build-qemu'
        expect(result_path['qemu_config']).to eq 'x86_64-softmmu'
        expect(result_path['qemu_commit']).to eq 'a58047f7fbb055677e45c9a7d65ba40fbfad4b92'

        expect(result_path.parse_result_root('/result/build-dpdk/dpdk-rootfs/x86_64-native-linuxapp-gcc/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc/0')).to be true
        expect(result_path.parse_result_root('/result/build-dpdk/dpdk-rootfs/x86_64-native-linuxapp-gcc/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc/')).to be true
        expect(result_path.parse_result_root('/result/build-dpdk/dpdk-rootfs/x86_64-native-linuxapp-gcc/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc')).to be true
        expect(result_path['testcase']).to eq 'build-dpdk'
        expect(result_path['rootfs']).to eq 'dpdk-rootfs'
        expect(result_path['dpdk_config']).to eq 'x86_64-native-linuxapp-gcc'
        expect(result_path['dpdk_compiler']).to eq 'gcc-4.9'
        expect(result_path['dpdk_commit']).to eq '60c5c5692107abf4157d48493aa2dec01f6b97cc'

        expect(result_path.parse_result_root('/result/lkp-a03/hwinfo/performance-1/debian-x86_64.cgz/x86_64-rhel/0df1f2487d2f0d04703f142813d53615d62a1da4/')).to be true
        expect(result_path.parse_result_root('/result/lkp-a03/hwinfo/performance-1/debian-x86_64.cgz/x86_64-rhel/0df1f2487d2f0d04703f142813d53615d62a1da4')).to be true
        expect(result_path['testcase']).to eq 'hwinfo'
        expect(result_path['path_params']).to eq 'performance-1'
        expect(result_path['tbox_group']).to eq 'lkp-a03'
        expect(result_path['rootfs']).to eq 'debian-x86_64.cgz'
        expect(result_path['kconfig']).to eq 'x86_64-rhel'
        expect(result_path['compiler']).to eq 'gcc-4.9'
        expect(result_path['commit']).to eq '0df1f2487d2f0d04703f142813d53615d62a1da4'
      end
    end

    context 'when given invalid result root' do
      it 'fails' do
        result_path = described_class.new
        expect(result_path.parse_result_root('/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a2')).to be false
        expect(result_path.parse_result_root('/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/')).to be false
        expect(result_path.parse_result_root('/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9')).to be false
        expect(result_path.parse_result_root('/result/lkp-a03/hwinfo/performance-1/debian-x86_64.cgz/x86_64-rhel/0df1f2487d2f0d04703f142813d53615d62a1da')).to be false
        expect(result_path.parse_result_root('/result/lkp-a03/hwinfo/performance-1/debian-x86_64.cgz/x86_64-rhel/')).to be false
        expect(result_path.parse_result_root('/result/lkp-a03/hwinfo/performance-1/debian-x86_64.cgz/x86_64-rhel')).to be false

        expect(result_path.parse_result_root('/result/build-qemu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92/')).to be false

        expect(result_path.parse_result_root('/result/build-dpdk/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/x86_64-native-linuxapp-gcc/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc')).to be false
        expect(result_path.parse_result_root('/result/build-dpdk/x86_64-native-linuxapp-gcc/gcc/60c5c5692107abf4157d48493aa2dec01f6b97cc')).to be false
        expect(result_path.parse_result_root('/result/build-dpdk/x86_64-native-linuxapp-gcc/gcc/60c5c5692107abf4157d48493aa2dec01f6b97cc/0')).to be false
      end
    end
  end

  valid_dpdk_result_root = '/result/build-dpdk/dpdk-rootfs/x86_64-native-linuxapp-gcc/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc/0'
  valid_qemu_result_root = '/result/build-qemu/x86_64-softmmu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92/2'

  describe '#each_commit' do
    it 'handles default path' do
      result_path = described_class.new

      result_path.parse_result_root('/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/2')

      result_path.each_commit do |project, commit_axis|
        expect(project).to eq 'linux'
        expect(commit_axis).to eq 'commit'
      end
    end

    it 'handles dpdk path' do
      result_path = described_class.new

      result_path.parse_result_root valid_dpdk_result_root

      project_mappings = Hash[result_path.each_commit.map { |project, commit_axis| [project, commit_axis] }]
      expect(project_mappings.size).to eq 2
      expect(project_mappings['linux']).to eq 'commit'
      expect(project_mappings['dpdk']).to eq 'dpdk_commit'
    end

    it 'handles qemu path' do
      result_path = described_class.new

      result_path.parse_result_root valid_qemu_result_root

      project_mappings = Hash[result_path.each_commit.map { |project, commit_axis| [project, commit_axis] }]
      expect(project_mappings.size).to eq 1
      expect(project_mappings['linux']).to eq nil
      expect(project_mappings['qemu']).to eq 'qemu_commit'
    end

    it 'returns enumerator' do
      result_path = described_class.new
      result_path.parse_result_root valid_dpdk_result_root

      expect(result_path.each_commit.any? { |project| project == 'dpdk' }).to be true
    end
  end

  describe '.maxis_keys' do
    it 'handles dpdk path' do
      expect(described_class.maxis_keys('build-dpdk').size).to eq 5
    end

    it 'handles qemu path' do
      expect(described_class.maxis_keys('build-qemu').size).to eq 2
    end
  end
end
