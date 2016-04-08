require 'spec_helper'
require "#{LKP_SRC}/lib/job"

describe Job do
	describe "project" do
		it "should recognize dpdk project" do
			job = Job.new
			job.load('/result/build-dpdk/x86_64-native-linuxapp-gcc/afd2ff9b7e1b367172f18ba7f693dfb62bdcb2dc/gcc-5/2e14846d15addd349a909176473e936f0cf79075/0/job.yaml')

			expect(job.project).to eq 'dpdk'
			job.each_jobs do |j|
				expect(j.project).to eq 'dpdk'
			end
		end

		it "should recognize qemu project" do
			job = Job.new
			job.load('/result/build-qemu/x86_64-softmmu/a58047f7fbb055677e45c9a7d65ba40fbfad4b92/2/job.yaml')

			expect(job.project).to eq 'qemu'
			job.each_jobs do |j|
				expect(j.project).to eq 'qemu'
			end
		end

		it "should recognize linux project" do
			job = Job.new
			job.load('/result/aim7/600-mem_rtns_1/lkp-a03/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/171912fdeb2159d6cbf60bda4d0438da9fb1c731/0/job.yaml')

			expect(job.project).to eq 'linux'
			job.each_jobs do |j|
				expect(j.project).to eq 'linux'
			end
		end
	end
end
