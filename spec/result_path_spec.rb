require 'spec_helper'
require "#{LKP_SRC}/lib/result"

describe ResultPath do
  describe '#parse_result_root' do
    context 'when given valid result root' do
      it 'succeeds' do
        result_path = described_class.new

        expect(result_path.parse_result_root("#{RESULT_MNT}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/2")).to be true
        expect(result_path.parse_result_root("#{RESULT_MNT}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/")).to be true
        expect(result_path.parse_result_root("#{RESULT_MNT}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27")).to be true
        expect(result_path['testcase']).to eq 'aim7'
        expect(result_path['path_params']).to eq 'performance-2000-fork_test'
        expect(result_path['ucode']).to eq nil
        expect(result_path['tbox_group']).to eq 'brickland3'
        expect(result_path['rootfs']).to eq 'debian-x86_64-2015-02-07.cgz'
        expect(result_path['kconfig']).to eq 'x86_64-rhel'
        expect(result_path['compiler']).to eq 'gcc-4.9'
        expect(result_path['commit']).to eq '0f57d86787d8b1076ea8f9cbdddda2a46d534a27'

        expect(result_path.parse_result_root("#{RESULT_MNT}/will-it-scale/performance-thread-100%-brk1-ucode=0x20/lkp-ivb-d01/debian-x86_64-2018-04-03.cgz/x86_64-rhel-7.2/gcc-7/8fe28cb58bcb235034b64cbbb7550a8a43fd88be/0")).to be true
        expect(result_path['ucode']).to eq '0x20'
        expect(result_path.parse_result_root("#{RESULT_MNT}/hackbench/1600%-process-pipe-ucode=0x20-performance/lkp-ivb-d01/debian-x86_64-2018-04-03.cgz/x86_64-rhel-7.2/gcc-7/017c4be4feb493ba63d51bed02225c136820bdf7")).to be true
        expect(result_path['ucode']).to eq '0x20'

        expect(result_path.parse_result_root("#{RESULT_MNT}/build-qemu/clear-ota-25590-x86_64-2018-10-18.cgz/x86_64-softmmu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92/2")).to be true
        expect(result_path.parse_result_root("#{RESULT_MNT}/build-qemu/debian-x86_64-2018-04-03.cgz/x86_64-softmmu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92/")).to be true
        expect(result_path.parse_result_root("#{RESULT_MNT}/build-qemu/debian-x86_64-2018-04-03.cgz/x86_64-softmmu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92")).to be true
        expect(result_path['testcase']).to eq 'build-qemu'
        expect(result_path['rootfs']).to eq 'debian-x86_64-2018-04-03.cgz'
        expect(result_path['qemu_config']).to eq 'x86_64-softmmu'
        expect(result_path['qemu_commit']).to eq 'a58047f7fbb055677e45c9a7d65ba40fbfad4b92'

        expect(result_path.parse_result_root("#{RESULT_MNT}/build-dpdk/dpdk-rootfs/x86_64-native-linuxapp-gcc/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc/0")).to be true
        expect(result_path.parse_result_root("#{RESULT_MNT}/build-dpdk/dpdk-rootfs/x86_64-native-linuxapp-gcc/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc/")).to be true
        expect(result_path.parse_result_root("#{RESULT_MNT}/build-dpdk/dpdk-rootfs/x86_64-native-linuxapp-gcc/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc")).to be true
        expect(result_path['testcase']).to eq 'build-dpdk'
        expect(result_path['rootfs']).to eq 'dpdk-rootfs'
        expect(result_path['dpdk_config']).to eq 'x86_64-native-linuxapp-gcc'
        expect(result_path['dpdk_compiler']).to eq 'gcc-4.9'
        expect(result_path['dpdk_commit']).to eq '60c5c5692107abf4157d48493aa2dec01f6b97cc'
      end
    end

    context 'when given invalid result root' do
      it 'fails' do
        result_path = described_class.new
        expect(result_path.parse_result_root("#{RESULT_MNT}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a2")).to be false
        expect(result_path.parse_result_root("#{RESULT_MNT}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/")).to be false
        expect(result_path.parse_result_root("#{RESULT_MNT}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9")).to be false

        expect(result_path.parse_result_root("#{RESULT_MNT}/build-qemu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92/")).to be false

        expect(result_path.parse_result_root("#{RESULT_MNT}/build-dpdk/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/x86_64-native-linuxapp-gcc/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc")).to be false
        expect(result_path.parse_result_root("#{RESULT_MNT}/build-dpdk/x86_64-native-linuxapp-gcc/gcc/60c5c5692107abf4157d48493aa2dec01f6b97cc")).to be false
        expect(result_path.parse_result_root("#{RESULT_MNT}/build-dpdk/x86_64-native-linuxapp-gcc/gcc/60c5c5692107abf4157d48493aa2dec01f6b97cc/0")).to be false
      end
    end
  end

  valid_dpdk_result_root = "#{RESULT_MNT}/build-dpdk/dpdk-rootfs/x86_64-native-linuxapp-gcc/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc/0"
  valid_qemu_result_root = "#{RESULT_MNT}/build-qemu/x86_64-softmmu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92/2"

  describe '#each_commit' do
    it 'handles default path' do
      result_path = described_class.new

      result_path.parse_result_root("#{RESULT_MNT}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/2")

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
      expect(described_class.maxis_keys('build-qemu').size).to eq 3
    end
  end
end
