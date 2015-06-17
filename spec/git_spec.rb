require 'rspec'

# a hack to append customised path to the end due to several name duplications
# of lib files, like yaml.rb, time.rb
$LOAD_PATH.concat($LOAD_PATH.shift(3))

ENV['LKP_SRC'] = File.expand_path "#{File.dirname(__FILE__)}/.."
ENV['GIT_WORK_TREE'] = File.expand_path "#{File.dirname(__FILE__)}/.."

require 'lkp_git'
require "git-update"

describe Git do
	COMMIT = "aa5067e781217fe698ee55e993e1465b83b5d65e"

	describe Git::Object::Commit do
		it "should have same output as lkp git" do
			git = LkpGit.init
			gcommit = git.gcommit(COMMIT)

			expect(gcommit.author.formatted_name).to eq(git_commit_author(COMMIT))
			expect(gcommit.committer.formatted_name).to eq(git_committer(COMMIT))
			expect(gcommit.subject).to eq(git_commit_subject(COMMIT))
			expect(gcommit.date).to eq(git_commit_time(COMMIT))
			expect(gcommit.interested_tag).to eq(commit_tag(COMMIT))
			expect(gcommit.parent_shas).to eq(git_parent_commits(COMMIT))
			expect(gcommit.committer.name).to eq(git_committer_name(COMMIT))
		end

		it "should cache interested_tag" do
			git = LkpGit.init
			gcommit = git.gcommit(COMMIT)

			expect(gcommit.interested_tag.object_id).to eq(gcommit.interested_tag.object_id)
		end
	end

	describe Git::Base do
		it "should cache commits of single git object" do
			git = LkpGit.init

			gcommit1 = git.gcommit(COMMIT)
			gcommit2 = git.gcommit(COMMIT)
			expect(gcommit2.object_id).to eq gcommit1.object_id

			expect(gcommit2.committer.name.object_id).to eq gcommit2.committer.name.object_id
		end

		it "should cache commits of multiple git objects" do
			git1 = LkpGit.init
			git2 = LkpGit.init
			expect(git2.object_id).not_to eq git1.object_id

			expect(git2.gcommit(COMMIT).object_id).to eq git1.gcommit(COMMIT).object_id
		end
	end
end
