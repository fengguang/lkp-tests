require 'rspec'
require 'dmesg'

describe "Dmesg" do
	describe "analyze_bisect_pattern" do
		it "should compress special cases" do
			line, bug_to_bisect = analyze_error_id "[   61.268659] Corrupted low memory at ffff880000007b08 (7b08 phys) = 27200c000000000"
			expect(line).to eq "Corrupted_low_memory_at#(#phys)=: 1"
			expect(bug_to_bisect).to eq "Corrupted low memory at"
		end
	end
end
