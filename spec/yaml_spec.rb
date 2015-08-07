require 'rspec'

$LOAD_PATH.concat($LOAD_PATH.shift(3))

require "#{ENV['LKP_SRC']}/lib/yaml"

describe WTMP do
	describe "load" do
		it "should handle control character" do
			result = described_class.load("time: 2015-08-06 20:25:44 +0800\nstate: running\n\ntime: 2015-08-06 20:29:21 +0800\nstate: finished\n\n\u0000\u0000\u0000\u0000")

			expect(result['state']).to eq 'finished'
		end
	end

	describe "load_tail" do
		it "should return nil if error" do
			result = described_class.load_tail("time: 2015-08-06 20:25:44 +0800state: running")
			expect(result).to be nil
		end
	end
end

