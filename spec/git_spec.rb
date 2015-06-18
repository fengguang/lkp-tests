require 'rspec'

# a hack to append customised path to the end due to several name duplications
# of lib files, like yaml.rb, time.rb
$LOAD_PATH.concat($LOAD_PATH.shift(3))

ENV['LKP_SRC'] = File.expand_path "#{File.dirname(__FILE__)}/.."

require 'lkp_git'
require "git-update"

describe Git do
	context "linux" do
		# tag v4.1-rc8
		LINUX_RELEASE_COMMIT = "0f57d86787d8b1076ea8f9cbdddda2a46d534a27"
		LINUX_NON_RELEASE_COMMIT = "b86a7563ca617aa49dfd6b836da4dd0351fe2acc"

		describe Git::Object::Commit do
			it "should have same output as lkp git" do
				git = Git.project_init
				gcommit = git.gcommit(LINUX_RELEASE_COMMIT)

				expect(gcommit.author.formatted_name).to eq(git_commit_author(LINUX_RELEASE_COMMIT))
				expect(gcommit.committer.formatted_name).to eq(git_committer(LINUX_RELEASE_COMMIT))
				expect(gcommit.subject).to eq(git_commit_subject(LINUX_RELEASE_COMMIT))
				expect(gcommit.date).to eq(git_commit_time(LINUX_RELEASE_COMMIT))
				expect(gcommit.interested_tag).to eq(commit_tag(LINUX_RELEASE_COMMIT))
				expect(gcommit.parent_shas).to eq(git_parent_commits(LINUX_RELEASE_COMMIT))
				expect(gcommit.committer.name).to eq(git_committer_name(LINUX_RELEASE_COMMIT))
			end

			it "should handle non ascii chars" do
				git = Git.project_init(project: "ukl")

				# commit 8d0977811d6741b8600886736712387aa8c434a9
				# Author: Uwe Kleine-König <u.kleine-koenig@pengutronix.de>
				# Date:   Mon Nov 18 11:40:16 2013 +0100
				gcommit = git.gcommit("8d0977811d6741b8600886736712387aa8c434a9")

				expect(gcommit.author.formatted_name).to eq('Uwe Kleine-König <u.kleine-koenig@pengutronix.de>')
				expect(gcommit.interested_tag).to eq nil
			end

			it "should cache interested_tag" do
				git = Git.project_init
				gcommit = git.gcommit(LINUX_RELEASE_COMMIT)

				expect(gcommit.interested_tag.object_id).to eq(gcommit.interested_tag.object_id)
			end

			describe "release_tag" do
				it "should be same as linus_release_tag with default arguments" do
					git = Git.project_init

					expect(git.gcommit(LINUX_RELEASE_COMMIT).release_tag).to eq(linus_release_tag(LINUX_RELEASE_COMMIT))

					expect(git.gcommit(LINUX_NON_RELEASE_COMMIT).release_tag).to eq nil
					expect(git.gcommit(LINUX_NON_RELEASE_COMMIT).release_tag).to eq(linus_release_tag(LINUX_NON_RELEASE_COMMIT))
				end
			end

			describe "base_release_tag" do
				it "should be same as last_linus_release_tag with default arguments" do
					git = Git.project_init

					expect(git.gcommit(LINUX_RELEASE_COMMIT).base_release_tag).to eq(["v4.1-rc8", true])
					expect(git.gcommit(LINUX_RELEASE_COMMIT).base_release_tag).to eq(last_linus_release_tag(LINUX_RELEASE_COMMIT))

					v2_6_13_commit = "02b3e4e2d71b6058ec11cc01c72ac651eb3ded2b"
					expect(git.gcommit(v2_6_13_commit).base_release_tag).to eq(["v2.6.13", true])
					expect(git.gcommit(v2_6_13_commit).base_release_tag).to eq(last_linus_release_tag(v2_6_13_commit))

					v2_6_13_child_commit = "af36d7f0df56de3e3e4bbfb15d0915097ecb8cab"
					expect(git.gcommit(v2_6_13_child_commit).base_release_tag).to eq(["v2.6.13-rc7", false])
					expect(git.gcommit(v2_6_13_child_commit).base_release_tag).to eq(last_linus_release_tag(v2_6_13_child_commit))
				end

				it "should cache result" do
					git = Git.project_init

					v2_6_13_child_commit = "af36d7f0df56de3e3e4bbfb15d0915097ecb8cab"
					expect(git.gcommit(v2_6_13_child_commit).base_release_tag.object_id).to eq git.gcommit(v2_6_13_child_commit).base_release_tag.object_id
				end
			end
		end

		describe Git::Base do
			it "should cache commits of single git object" do
				git = Git.project_init

				gcommit1 = git.gcommit(LINUX_RELEASE_COMMIT)
				gcommit2 = git.gcommit(LINUX_RELEASE_COMMIT)
				expect(gcommit2.object_id).to eq gcommit1.object_id

				expect(gcommit2.committer.name.object_id).to eq gcommit2.committer.name.object_id
			end

			it "should cache commits of multiple git objects" do
				git1 = Git.project_init
				git2 = Git.project_init
				expect(git2.object_id).not_to eq git1.object_id

				expect(git2.gcommit(LINUX_RELEASE_COMMIT).object_id).to eq git1.gcommit(LINUX_RELEASE_COMMIT).object_id
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

	context "gcc" do
		# tag gcc-5_1_0-release
		GCC_RELEASE_COMMIT = "d5ad84b309d0d97d3955fb1f62a96fc262df2b76"

		#
		# $ git cat-file commit d5ad84b309d0d97d3955fb1f62a96fc262df2b76
		# tree a9366b5b9ea62a23412a74bb1a0f0753da94b683
		# parent 9a2ae78f8140d02ca684fdbadfe09cbbbfd5c27f
		# author gccadmin <gccadmin@138bc75d-0d04-0410-961f-82ee72b054a4> 1429692192 +0000
		# committer gccadmin <gccadmin@138bc75d-0d04-0410-961f-82ee72b054a4> 1429692192 +0000
		#
		# Update ChangeLog and version files for release

		describe Git::Object::Commit do
			it "should be correct" do
				git = Git.project_init(project: 'gcc')

				gcommit = git.gcommit(GCC_RELEASE_COMMIT)

				expect(gcommit.author.formatted_name).to eq('gccadmin <gccadmin@138bc75d-0d04-0410-961f-82ee72b054a4>')
				expect(gcommit.committer.formatted_name).to eq gcommit.author.formatted_name
				expect(gcommit.subject).to eq("Update ChangeLog and version files for release")
				#expect(gcommit.interested_tag).to eq(commit_tag(GCC_RELEASE_COMMIT))
				expect(gcommit.parent_shas).to eq(["9a2ae78f8140d02ca684fdbadfe09cbbbfd5c27f"])
				expect(gcommit.committer.name).to eq('gccadmin')
			end
		end
	end

end
