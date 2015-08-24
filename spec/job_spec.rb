require 'rspec'

$LOAD_PATH.concat($LOAD_PATH.shift(3))

require 'job'

describe Job do
	describe "project" do
		it "should recognize dpdk project" do
			job = Job.new
			job.load('/result/build-dpdk/x86_64-native-linuxapp-gcc/gcc/7173acefc7cfdfbbb9b91fcba1c9a67adb4c07c9/0/job.yaml')

			expect(job.project).to eq 'dpdk'
			job.each_jobs do |j|
				expect(j.project).to eq 'dpdk'
			end
		end

		it "should recognize linux project" do
			job = Job.new
			job.load('/result/aim7/performance-2000-fork_test/brickland3/debian-x86_64-2015-02-07.cgz/x86_64-rhel/gcc-4.9/0f57d86787d8b1076ea8f9cbdddda2a46d534a27/0/job.yaml')

			expect(job.project).to eq 'linux'
			job.each_jobs do |j|
				expect(j.project).to eq 'linux'
			end
		end
	end
end
