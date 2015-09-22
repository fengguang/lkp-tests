LKP_SRC ||= ENV['LKP_SRC']

require "#{LKP_SRC}/lib/job.rb"
require "#{LKP_SRC}/lib/misc.rb"

# JobFeedback: to log job feedbacks for later queries
class JobFeedback
	JOB_FEEDBACK_ROOT = "/lkp/#{ENV['USER']}/job-feedback"

	def self.new_feedback(job_file)
		job = Job.new
		job.load job_file

		dir = JOB_FEEDBACK_ROOT + Time.now.strftime('/%Y/%m/')
		check_create_lkp_dir dir

		feedback_file = dir + Time.now.strftime('%d__%T.%N')
		job['feedback_file'] = feedback_file
		job.save(job_file)

		self.append_job_state     job, "feedback_initiated"
		self.update_job_file_path job_file
	end

	# feedback file path is stored at a job file. Hence, you have three
	# ways to find it(that's what feedback_file_path_carrier meant to):
	#   - feedback_file          (telling the feedback file path directly)
	#   - job['feedback_file']   (job might be of Hash class or Job class)
	#   - job_file               (job_file -> job_hash -> feedback_file)
	def self.append(feedback_file_path_carrier, k, v)
		fb_file = case feedback_file_path_carrier
			when String
				# is it a feedback_file path?
				if feedback_file_path_carrier.index(JOB_FEEDBACK_ROOT)
					feedback_file_path_carrier
				else
					job_hash = YAML.load_file feedback_file_path_carrier
					job_hash['feedback_file']
				end
			when Hash, Job
				feedback_file_path_carrier['feedback_file']
			else
				raise "wrong feedback file path carrier: #{feedback_file_path_carrier}"
			end

		return if not fb_file

		File.open(fb_file, mode='a') { |f|
			f.puts "#{k}: #{v}"
		}
	end

	# when we want to note down a job state like "job_state: finished",
	# we acutally end up with noting down:
	#     job_state: finished
	#     finished_time: Time.now
	def self.append_job_state(feedback_file_path_carrier, job_state)
		self.append feedback_file_path_carrier, "job_state",         job_state
		self.append feedback_file_path_carrier, "#{job_state}_time", Time.now
	end

	# every time you move the job file to somewhere, you need to
	# invoke this method to update the latest job file path. So
	# that we could detect whether a job file is deleted by user.
	def self.update_job_file_path(job_file)
		self.append job_file, "job_file", job_file
	end
end

# JobFeedbackQuery: query job feebacks
class JobFeedbackQuery
	def initialize(job_file)
		job_hash = YAML.load_file job_file

		@feedback_file = job_hash['feedback_file'] || ""
	end

	def feedback
		if not File.exist?(@feedback_file)
			$stderr.puts "no feedback given!"
			return nil
		end

		# need to reload to get latest state
		YAML.load_file @feedback_file
	end

	def job_desc
		self.feedback['job_desc']
	end

	def job_state
		self.feedback['job_state']
	end

	def job_state=(state)
		JobFeedback.append_job_state @feedback_file, state
	end

	# >= 0 means a normal state
	# <  0 means an abnormal state
	# TODO: introduce JobState class, so that we could use job_state.to_i?
	def job_state_int(js = self.job_state)
		case js
		when 'enqueued'
			0
		when 'scheduled'
			1
		when 'booting'
			2
		when 'running'
			3
		when 'finished'
			4
		when 'processed_1st_stage'
			5
		when 'united'
			6

		when 'deleted.kernel_boot_fails'
			-1
		when 'deleted.got_enought_results'
			-2
		when 'deleted.cancelled'
			-3
		else
			-4
		end
	end

	def job_runtime
		(self.feedback['finished_time'] - self.feedback['running_time']) rescue -1
	end

	def job_successfull_finished?
		self.job_state == "united"
	end

	def job_failed?
		self.job_state_int < 0
	end

	def job_cancelled?
		return false if File.exist?(self.feedback['job_file'])

		self.job_state = "deleted.cancelled"
		puts ":: #{self.job_desc}: cancelled. Deleted by user?" if ENV['LKP_VERBOSE']
		return true
	end

	# wait for a job being done(it could be unsuccessful, or even cancelled).
	#
	# return the time we start executing it(scheduled time). If it's not scheduled,
	# reutrn the time we set last job state.
	def wait_for_job
		loop {
			puts ":: #{self.feedback['job_desc']}: #{self.job_state}" if ENV['LKP_VERBOSE']

			break if self.job_successfull_finished? or
				 self.job_failed?               or
				 self.job_cancelled?

			# otherwise, the job is still in the queue or running; let's wait
			sleep 60
		}

		return self.feedback['scheduled_time'] || self.feedback["#{self.job_state}_time"]
	end
end

def test
	job_file = "/tmp/job-feedback-test.yaml"
	%x[ echo job: faked > #{job_file} ]

	JobFeedback.new_feedback     job_file
	JobFeedback.append_job_state job_file, "running"
	sleep 1
	JobFeedback.append_job_state job_file, "finished"

	job_feedback_query = JobFeedbackQuery.new job_file
	puts "job_state: "   + job_feedback_query.job_state
	puts "job_runtime: " + job_feedback_query.job_runtime.to_s

	job_feedback_query.job_state = "united"
	puts "job_state: " + job_feedback_query.job_state
end
#test
