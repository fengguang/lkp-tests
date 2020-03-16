require 'spec_helper'
require "#{LKP_SRC}/lib/result"

describe ResultPath do
  describe '#parse_result_root' do
    context 'handles default path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/2")).to be true
          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/")).to be true
          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27")).to be true
          expect(result_path['testcase']).to eq 'aim7'
          expect(result_path['path_params']).to eq 'performance-2000-fork_test'
          expect(result_path['ucode']).to eq nil
          expect(result_path['tbox_group']).to eq 'brickland3'
          expect(result_path['rootfs']).to eq 'debian-x86_64-2015-02-07.cgz'
          expect(result_path['kconfig']).to eq 'x86_64-rhel'
          expect(result_path['compiler']).to eq 'gcc-4.9'
          expect(result_path['commit']).to eq '0f57d86787d8b1076ea8f9cbdddda2a46d534a27'

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/will-it-scale/performance-thread-100%-brk1-ucode=0x20/lkp-ivb-d01/debian-x86_64-20180403.cgz/x86_64-rhel-7.2/gcc-7/8fe28cb58bcb235034b64cbbb7550a8a43fd88be/0")).to be true
          expect(result_path['ucode']).to eq '0x20'
          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/hackbench/1600%-process-pipe-ucode=0x20-performance/lkp-ivb-d01/debian-x86_64-20180403.cgz/x86_64-rhel-7.2/gcc-7/017c4be4feb493ba63d51bed02225c136820bdf7")).to be true
          expect(result_path['ucode']).to eq '0x20'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a2")).to be false
          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/")).to be false
          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9")).to be false
        end
      end
    end

    context 'handles build-qemu path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-qemu/clear-x86_64-ota-25590-20181018.cgz/x86_64-softmmu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92/2")).to be true
          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-qemu/debian-x86_64-20180403.cgz/x86_64-softmmu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92/")).to be true
          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-qemu/debian-x86_64-20180403.cgz/x86_64-softmmu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92")).to be true
          expect(result_path['testcase']).to eq 'build-qemu'
          expect(result_path['rootfs']).to eq 'debian-x86_64-20180403.cgz'
          expect(result_path['qemu_config']).to eq 'x86_64-softmmu'
          expect(result_path['qemu_commit']).to eq 'a58047f7fbb055677e45c9a7d65ba40fbfad4b92'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-qemu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92/")).to be false
        end
      end
    end

    context 'handles build-dpdk path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-dpdk/dpdk-rootfs/x86_64-native-linuxapp-gcc/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc/0")).to be true
          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-dpdk/dpdk-rootfs/x86_64-native-linuxapp-gcc/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc/")).to be true
          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-dpdk/dpdk-rootfs/x86_64-native-linuxapp-gcc/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc")).to be true
          expect(result_path['testcase']).to eq 'build-dpdk'
          expect(result_path['rootfs']).to eq 'dpdk-rootfs'
          expect(result_path['dpdk_config']).to eq 'x86_64-native-linuxapp-gcc'
          expect(result_path['dpdk_compiler']).to eq 'gcc-4.9'
          expect(result_path['dpdk_commit']).to eq '60c5c5692107abf4157d48493aa2dec01f6b97cc'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-dpdk/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/x86_64-native-linuxapp-gcc/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc")).to be false
          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-dpdk/x86_64-native-linuxapp-gcc/gcc/60c5c5692107abf4157d48493aa2dec01f6b97cc")).to be false
          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-dpdk/x86_64-native-linuxapp-gcc/gcc/60c5c5692107abf4157d48493aa2dec01f6b97cc/0")).to be false
        end
      end
    end

    context 'handles kvm:default path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/kvm:vm-scalability/performance-300s-lru-file-mmap-read-rand-ucode=0x2000065/lkp-skl-2sp7/debian-x86_64-20191114.cgz/x86_64-rhel-7.6/gcc-7/7472c4028e2357202949f99ad94c5a5a34f95666/0")).to be true
          expect(result_path['testcase']).to eq 'kvm:vm-scalability'
          expect(result_path['path_params']).to eq 'performance-300s-lru-file-mmap-read-rand-ucode=0x2000065'
          expect(result_path['tbox_group']).to eq 'lkp-skl-2sp7'
          expect(result_path['rootfs']).to eq 'debian-x86_64-20191114.cgz'
          expect(result_path['kconfig']).to eq 'x86_64-rhel-7.6'
          expect(result_path['compiler']).to eq 'gcc-7'
          expect(result_path['commit']).to eq '7472c4028e2357202949f99ad94c5a5a34f95666'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/kvm:vm-scalability/lkp-skl-2sp7/debian-x86_64-20191114.cgz/x86_64-rhel-7.6/gcc-7/7472c4028e2357202949f99ad94c5a5a34f95666/")).to be false
          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/kvm:vm-scalability/performance-300s-lru-file-mmap-read-rand-ucode=0x2000065/lkp-skl-2sp7/debian-x86_64-20191114.cgz/x86_64-rhel-7.6/gcc-7/747")).to be false
        end
      end
    end

    context 'handles hwinfo path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/hwinfo/lkp-bdw-ep6/1")).to be true
          expect(result_path['testcase']).to eq 'hwinfo'
          expect(result_path['tbox_group']).to eq 'lkp-bdw-ep6'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/hwinfo")).to be false
        end
      end
    end

    context 'handles build-llvm_project path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-llvm_project/debian-x86_64-20191114.cgz/073dbaae39724ea860b5957fe47ecc1c2a84b197/0")).to be true
          expect(result_path['testcase']).to eq 'build-llvm_project'
          expect(result_path['rootfs']).to eq 'debian-x86_64-20191114.cgz'
          expect(result_path['llvm_project_commit']).to eq '073dbaae39724ea860b5957fe47ecc1c2a84b197'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-llvm_project/debian-x86_64-20191114.cgz")).to be false
        end
      end
    end

    context 'handles deploy-clang path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/deploy-clang/debian-x86_64-20191114.cgz/073dbaae39724ea860b5957fe47ecc1c2a84b197/0")).to be true
          expect(result_path['testcase']).to eq 'deploy-clang'
          expect(result_path['rootfs']).to eq 'debian-x86_64-20191114.cgz'
          expect(result_path['llvm_project_commit']).to eq '073dbaae39724ea860b5957fe47ecc1c2a84b197'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/deploy-clang/65b21282c710afe9c275778820c6e3c1")).to be false
        end
      end
    end

    context 'handles build-nvml path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-nvml/debian-x86_64-20180403.cgz/28070d6f6c3e8465f2b0fbceccd5f72f12cdd866")).to be true
          expect(result_path['testcase']).to eq 'build-nvml'
          expect(result_path['rootfs']).to eq 'debian-x86_64-20180403.cgz'
          expect(result_path['nvml_commit']).to eq '28070d6f6c3e8465f2b0fbceccd5f72f12cdd866'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-nvml/debian-x86_64-20190319.cgz/")).to be false
        end
      end
    end

    context 'handles build-ltp path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-ltp/debian-x86_64-20191114.cgz/6c0870b78354d3511ae42882c25353b53956e185")).to be true
          expect(result_path['testcase']).to eq 'build-ltp'
          expect(result_path['rootfs']).to eq 'debian-x86_64-20191114.cgz'
          expect(result_path['ltp_commit']).to eq '6c0870b78354d3511ae42882c25353b53956e185'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-ltp/debian-x86_64-20191114.cgz/")).to be false
        end
      end
    end

    context 'handles build-acpica path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-acpica/3d047ea358a224d44352f9498ab140cb8c8973a1/unix")).to be true
          expect(result_path['testcase']).to eq 'build-acpica'
          expect(result_path['acpica_commit']).to eq '3d047ea358a224d44352f9498ab140cb8c8973a1'
          expect(result_path['test']).to eq 'unix'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-acpica/unix")).to be false
        end
      end
    end

    context 'handles build-ceph path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-ceph/3d047ea358a224d44352f9498ab140c")).to be true
          expect(result_path['testcase']).to eq 'build-ceph'
          expect(result_path['ceph_commit']).to eq '3d047ea358a224d44352f9498ab140c'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-ceph")).to be false
        end
      end
    end

    context 'handles kvm-unit-tests-qemu path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/kvm-unit-tests-qemu/ucode=0x200004d/lkp-skl-2sp4/debian-x86_64-20180403.cgz/x86_64-rhel-7.2/gcc-7/2595646791c319cadfdbf271563aac97d0843dc7/x86_64-softmmu/359c41abe32638adad503e386969fa428cecff52")).to be true
          expect(result_path['testcase']).to eq 'kvm-unit-tests-qemu'
          expect(result_path['path_params']).to eq 'ucode=0x200004d'
          expect(result_path['tbox_group']).to eq 'lkp-skl-2sp4'
          expect(result_path['rootfs']).to eq 'debian-x86_64-20180403.cgz'
          expect(result_path['kconfig']).to eq 'x86_64-rhel-7.2'
          expect(result_path['compiler']).to eq 'gcc-7'
          expect(result_path['commit']).to eq '2595646791c319cadfdbf271563aac97d0843dc7'
          expect(result_path['qemu_config']).to eq 'x86_64-softmmu'
          expect(result_path['qemu_commit']).to eq '359c41abe32638adad503e386969fa428cecff52'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/kvm-unit-tests-qemu/ucode=0x200004d/lkp-skl-2sp4//x86_64-rhel-7.2/gcc-7/2595646791c319cadfdbf271563aac97d0843dc7")).to be false
        end
      end
    end

    context 'handles kvm-kernel-boot-test path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/kvm-kernel-boot-test/lkp-csl-2sp7/x86_64-rhel-7.6/0ecfebd2b52404ae0c54a878c872bb93363ada36/x86_64-softmmu/fb2246882a2c8d7f084ebe0617e97ac78467d156/2595646791c319cadfdbf271563aac97d0843dc7/0/")).to be true
          expect(result_path['testcase']).to eq 'kvm-kernel-boot-test'
          expect(result_path['tbox_group']).to eq 'lkp-csl-2sp7'
          expect(result_path['kconfig']).to eq 'x86_64-rhel-7.6'
          expect(result_path['commit']).to eq '0ecfebd2b52404ae0c54a878c872bb93363ada36'
          expect(result_path['qemu_config']).to eq 'x86_64-softmmu'
          expect(result_path['qemu_commit']).to eq 'fb2246882a2c8d7f084ebe0617e97ac78467d156'
          expect(result_path['linux_commit']).to eq '2595646791c319cadfdbf271563aac97d0843dc7'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/kvm-kernel-boot-test/lkp-csl-2sp7/x86_64-rhel-7.6/")).to be false
        end
      end
    end

    context 'handles build-perf_test path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-perf_test/6367bd5b7304e6a309a5ef3387d44aa6f49cfc71")).to be true
          expect(result_path['testcase']).to eq 'build-perf_test'
          expect(result_path['perf_test_commit']).to eq '6367bd5b7304e6a309a5ef3387d44aa6f49cfc71'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/build-perf_test/")).to be false
        end
      end
    end

    context 'handles health-stats path' do
      context 'when valid result root' do
        it 'succesds' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/health-stats/__date_+%F_-d_yesterday_/0")).to be true
          expect(result_path['testcase']).to eq 'health-stats'
          expect(result_path['path_params']).to eq '__date_+%F_-d_yesterday_'
        end
      end
      context 'when invalid result root' do
        it 'fails' do
          result_path = described_class.new

          expect(result_path.parse_result_root("#{RESULT_ROOT_DIR}/health-stats")).to be false
        end
      end
    end
  end

  valid_dpdk_result_root = "#{RESULT_ROOT_DIR}/build-dpdk/dpdk-rootfs/x86_64-native-linuxapp-gcc/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/gcc-4.9/60c5c5692107abf4157d48493aa2dec01f6b97cc/0"
  valid_qemu_result_root = "#{RESULT_ROOT_DIR}/build-qemu/x86_64-softmmu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92/2"

  describe '#each_commit' do
    it 'handles default path' do
      result_path = described_class.new

      result_path.parse_result_root("#{RESULT_ROOT_DIR}/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/2")

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
