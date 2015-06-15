require 'rspec'

ENV['GIT_WORK_TREE'] = File.expand_path "#{File.dirname(__FILE__)}/.."

require 'lkp_git'

describe Git do
	describe "git gcommit" do

		COMMIT = "aa5067e781217fe698ee55e993e1465b83b5d65e"

		it "should be same as git_committer" do
			git = LkpGit.init

			gcommit = git.gcommit(COMMIT)
			expect(gcommit.author.formatted_name).to eq(git_commit_author(COMMIT))
			expect(gcommit.committer.formatted_name).to eq(git_committer(COMMIT))

			#expect(gcommit.date).to eq(git_commit_time(COMMIT))
		end
	end
end
