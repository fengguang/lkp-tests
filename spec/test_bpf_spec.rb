require 'spec_helper'

describe 'parse result' do
	context "when result not have keyword 'jited' and 'check'" do
			it 'returns formatted result' do
				actual = `echo "[   15.423329] test_bpf: #255 BPF_MAXINSNS: Too many instructions PASS" | #{LKP_SRC}/stats/test_bpf`
				expect(actual).to include('BPF_MAXINSNS:_Too_many_instructions.pass: 1')
			end
	end
end
