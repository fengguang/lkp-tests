require 'rspec'

# a hack to append customised path to the end due to several name duplications
# of lib files, like yaml.rb, time.rb
$LOAD_PATH.concat($LOAD_PATH.shift(3))

ENV['LKP_SRC'] = File.expand_path "#{File.dirname(__FILE__)}/.."

require 'lkp_git'
require "git-update"

describe Git do
	# commit from linux tree
	# tag v4.1-rc8
	COMMIT = "0f57d86787d8b1076ea8f9cbdddda2a46d534a27"

	describe Git::Object::Commit do
		it "should have same output as lkp git" do
			git = Git.project_init
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
			git = Git.project_init
			gcommit = git.gcommit(COMMIT)

			expect(gcommit.interested_tag.object_id).to eq(gcommit.interested_tag.object_id)
		end
	end

	describe Git::Base do
		it "should cache commits of single git object" do
			git = Git.project_init

			gcommit1 = git.gcommit(COMMIT)
			gcommit2 = git.gcommit(COMMIT)
			expect(gcommit2.object_id).to eq gcommit1.object_id

			expect(gcommit2.committer.name.object_id).to eq gcommit2.committer.name.object_id
		end

		it "should cache commits of multiple git objects" do
			git1 = Git.project_init
			git2 = Git.project_init
			expect(git2.object_id).not_to eq git1.object_id

			expect(git2.gcommit(COMMIT).object_id).to eq git1.gcommit(COMMIT).object_id
		end
	end

	describe "project_tags" do
		it "should be same as linus_tags when project is linux/linus" do
			actual = linus_tags
			expect = described_class.project_tags

			expect(expect.count).to be > 0
			expect(expect).to eq actual
		end

		it "should cache result" do
			expect(described_class.project_tags.object_id).to eq described_class.project_tags.object_id
		end
	end

	describe "project_remotes" do
		it "should be same as load_remotes when project is linux/linus" do
			actual = load_remotes
			expect = described_class.project_remotes

			expect(expect.count).to be > 0
			expect(expect).to eq actual
		end

		it "should cache result" do
			expect(described_class.project_remotes.object_id).to eq described_class.project_remotes.object_id
		end
	end
end
