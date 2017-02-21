require 'spec_helper'

describe 'parse result' do
  context "when result not have keyword 'jited' and 'check'" do
      it 'returns formatted result' do
        actual = `echo "[   15.423329] test_bpf: #255 BPF_MAXINSNS: Too many instructions PASS" | #{LKP_SRC}/stats/test_bpf`
        expect(actual).to include('BPF_MAXINSNS:_Too_many_instructions.pass: 1')
      end
  end
  context "when result not have keyword 'jited' and 'check'" do
      it 'returns formatted result' do
	stdout = <<EOF
[   24.541821] test_bpf: #278 LD_IND halfword positive offset
[   24.542612] [drm] GPU HANG: ecode 7:0:0x87c3ffff, reason: Hang on render ring, action: reset
[   24.542612] [drm] GPU hangs can indicate a bug anywhere in the entire gfx stack, including userspace.
[   24.542613] [drm] Please file a _new_ bug report on bugs.freedesktop.org against DRI -> DRM/Intel
[   24.542613] [drm] drm/i915 developers can then reassign to the right component if it's not a kernel issue.
[   24.542613] [drm] The gpu crash dump is required to analyze gpu hangs, so please always attach it.
[   24.542613] [drm] GPU crash dump saved to /sys/class/drm/card0/error
[   24.542629] drm/i915: Resetting chip after gpu hang
[   24.606705] jited:0
[   24.608842] 11 PASS
EOF
        actual = `echo "#{stdout}" | #{LKP_SRC}/stats/test_bpf`
        expect(actual).to include('LD_IND_halfword_positive_offset.pass: 1')
      end
  end
end
