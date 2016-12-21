require 'spec_helper'
require "#{LKP_SRC}/lib/dmesg"

describe DmesgTimestamp do
	VALID_MSG = '0-[   30.336811] [drm] Initialized mgag200 1.0.0 20110418 for 0000:11:00.0 on minor 0'.freeze
	INVALID_MSG = ' [   30.33681] [drm] Initialized mgag200 1.0.0 20110418 for 0000:11:00.0 on minor 0'.freeze

	describe '.valid?' do
		it 'is valid' do
			timestamp = described_class.new(VALID_MSG)
			expect(timestamp.valid?).to be true
		end

		it 'is invalid' do
			timestamp = described_class.new(INVALID_MSG)
			expect(timestamp.valid?).to be false
		end
	end

	describe '.<=>' do
		it 'is equal when two timestamps are both invalid' do
			timestamp1 = described_class.new(INVALID_MSG)
			timestamp2 = described_class.new(INVALID_MSG)

			expect(timestamp1 == timestamp2).to be true
			expect(timestamp1 <= timestamp2).to be true
			expect(timestamp1 < timestamp2).to be false
		end

		context 'when invalid' do
			before(:all) do
				@timestamp = described_class.new(INVALID_MSG)
			end

			it 'is less than any valid timestamp' do
				expect(@timestamp < described_class.new(VALID_MSG)).to be true
			end
		end

		context 'when valid' do
			before(:all) do
				@timestamp = described_class.new(VALID_MSG)
			end

			it 'is less than older timestamp' do
				expect(@timestamp < described_class.new('[   31.336811]')).to be true
			end

			it 'is larger than earlier timestamp' do
				expect(@timestamp > described_class.new('[   29.336811]')).to be true
			end

			it 'is larger than any invalid timestamp' do
				expect(@timestamp > described_class.new(INVALID_MSG)).to be true
			end
		end
	end

	describe DmesgTimestamp::AbnormalSequenceDetector do
		describe '.detected?' do
			def expect_detected(*dmesgs)
				*dmesgs, last_dmesg = dmesgs.flatten

				detector = described_class.new
				dmesgs.each do |line|
					expect(detector.detected?(line)).to be false
				end

				expect(detector.detected?(last_dmesg))
			end

			it 'detects normal sequence' do
				expect_detected('[ 0.000000]', '[ 0.000000]', '[ 0.000000]', '[ 0.000000]', '[ 0.000000]', '[ 0.000000]').to be false
				expect_detected('[ 1.000000]', '[ 0.100000]', '[ 0.200000]', '[ 0.300000]').to be false
				expect_detected('[ 1.000000]', '[ 0.100000]', '[ 0.200000]', '[ 0.300000]', '[ 0.100000]', '[ 0.200000]').to be false
			end

			it 'detects normal sequence 2' do
				dmesgs = ['[ 0.000000]', '[ 1.000000]', '[ 0.000000]', '[ 2.000000]', '[ 1.000000]',
				          '[ 0.100000]', '[ 0.200000]', '[ 0.300000]']

				expect_detected(dmesgs).to be false
			end

			it 'detects abnormal sequence' do
				dmesgs = ['[ 0.000000]', '[ 1.000000]', '[ 1.000000]', '[ 2.000000]', '[ 0.000000]',
				          '[ 0.900000]', '[ 0.000000]']

				expect_detected(dmesgs).to be true
			end

			it 'detects abnormal sequence 2' do
				dmesgs = ['[ 0.000000]', '[ 1.000000]', '[ 1.000000]', '[ 2.000000]', '[ 1.000000]',
				          '[ 0.100000]', '[ 0.200000]', '[ 0.300000]']

				expect_detected(dmesgs).to be true
			end
		end
	end
end
