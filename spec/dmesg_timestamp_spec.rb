require 'spec_helper'
require "#{LKP_SRC}/lib/dmesg"

describe DmesgTimestamp do
	VALID_MSG = "0-[   30.336811] [drm] Initialized mgag200 1.0.0 20110418 for 0000:11:00.0 on minor 0"
	INVALID_MSG = " [   30.33681] [drm] Initialized mgag200 1.0.0 20110418 for 0000:11:00.0 on minor 0"

	describe "valid?" do
		it "should be valid" do
			timestamp = described_class.new(VALID_MSG)
			expect(timestamp.valid?).to be true
		end

		it "should be invalid" do
			timestamp = described_class.new(INVALID_MSG)
			expect(timestamp.valid?).to be false
		end
	end

	describe "<=>" do
		it "should be equal when two timestamps are both invalid" do
			timestamp1 = described_class.new(INVALID_MSG)
			timestamp2 = described_class.new(INVALID_MSG)

			expect(timestamp1 == timestamp2).to be true
			expect(timestamp1 <= timestamp2).to be true
			expect(timestamp1 < timestamp2).to be false
		end

		it "should be less than another valid object when invalid or timestamp is earlier" do
			timestamp = described_class.new(VALID_MSG)

			expect(described_class.new(INVALID_MSG) < timestamp).to be true
			expect(described_class.new("[   29.336811]") < timestamp).to be true
		end

		it "should be larger than another invalid object when valid" do
			expect(described_class.new(VALID_MSG) > described_class.new(INVALID_MSG)).to be true
		end

		it "should be larger than another valid object when timestamp is older" do
			expect(described_class.new("[   31.336811]") > described_class.new(VALID_MSG)).to be true
		end
	end

	describe DmesgTimestamp::AbnormalSequenceDetector do
		describe "detected?" do
			def expect_detected(*dmesgs)
				dmesgs = dmesgs.flatten
				last_dmesg = dmesgs.pop

				detector = described_class.new
				dmesgs.each do |line|
					expect(detector.detected? line).to be false
				end

				expect(detector.detected? last_dmesg)
			end

			it "should detect normal sequence" do
				expect_detected("[ 0.000000]", "[ 0.000000]", "[ 0.000000]", "[ 0.000000]", "[ 0.000000]", "[ 0.000000]").to be false
				expect_detected("[ 1.000000]", "[ 0.100000]", "[ 0.200000]", "[ 0.300000]").to be false
				expect_detected("[ 1.000000]", "[ 0.100000]", "[ 0.200000]", "[ 0.300000]", "[ 0.100000]", "[ 0.200000]").to be false
			end

			it "should detect normal sequence 2" do
				dmesgs = ["[ 0.000000]", "[ 1.000000]", "[ 0.000000]", "[ 2.000000]", "[ 1.000000]",
				          "[ 0.100000]", "[ 0.200000]", "[ 0.300000]"]

				expect_detected(dmesgs).to be false
			end

			it "should detect abnormal sequence" do
				dmesgs = ["[ 0.000000]", "[ 1.000000]", "[ 1.000000]", "[ 2.000000]", "[ 0.000000]",
				          "[ 0.900000]", "[ 0.000000]"]

				expect_detected(dmesgs).to be true
			end

			it "should detect abnormal sequence 2" do
				dmesgs = ["[ 0.000000]", "[ 1.000000]", "[ 1.000000]", "[ 2.000000]", "[ 1.000000]",
				          "[ 0.100000]", "[ 0.200000]", "[ 0.300000]"]

				expect_detected(dmesgs).to be true
			end

		end
	end
end
