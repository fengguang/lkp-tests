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
		linux_v4_1_rc8_commit = "0f57d86787d8b1076ea8f9cbdddda2a46d534a27"
		linux_non_release_commit = "b86a7563ca617aa49dfd6b836da4dd0351fe2acc"

		describe Git::Object::Commit do
			before do
				@git = Git.project_init
			end

			it "should be same as lkp git" do
				gcommit = @git.gcommit(linux_v4_1_rc8_commit)

				expect(gcommit.author.formatted_name).to eq(git_commit_author(linux_v4_1_rc8_commit))
				expect(gcommit.committer.formatted_name).to eq(git_committer(linux_v4_1_rc8_commit))
				expect(gcommit.subject).to eq(git_commit_subject(linux_v4_1_rc8_commit))
				expect(gcommit.date).to eq(git_commit_time(linux_v4_1_rc8_commit))
				expect(gcommit.interested_tag).to eq(commit_tag(linux_v4_1_rc8_commit))
				expect(gcommit.parent_shas).to eq(git_parent_commits(linux_v4_1_rc8_commit))
				expect(gcommit.committer.name).to eq(git_committer_name(linux_v4_1_rc8_commit))
			end

			it "should handle non ascii chars" do
				git = Git.project_init(project: "ukl")

				# commit 8d0977811d6741b8600886736712387aa8c434a9
				# Author: Uwe Kleine-König <u.kleine-koenig@pengutronix.de>
				# Date:   Mon Nov 18 11:40:16 2013 +0100
				gcommit = git.gcommit("8d0977811d6741b8600886736712387aa8c434a9")

				expect(gcommit.author.formatted_name).to eq('Uwe Kleine-König <u.kleine-koenig@pengutronix.de>')
				#expect(gcommit.interested_tag).to eq nil
			end

			describe "interested_tag" do
				it "should cache result" do
					gcommit = @git.gcommit(linux_v4_1_rc8_commit)

					expect(gcommit.interested_tag.object_id).to eq(gcommit.interested_tag.object_id)
				end
			end

			describe "release_tag" do
				it "should be same as linus_release_tag with default arguments" do
					expect(@git.gcommit(linux_v4_1_rc8_commit).release_tag).to eq 'v4.1-rc8'
					expect(@git.gcommit(linux_v4_1_rc8_commit).release_tag).to eq(linus_release_tag(linux_v4_1_rc8_commit))

					expect(@git.gcommit(linux_non_release_commit).release_tag).to eq nil
					expect(@git.gcommit(linux_non_release_commit).release_tag).to eq(linus_release_tag(linux_non_release_commit))
				end

				it "should cache result" do
					expect(@git.gcommit(linux_v4_1_rc8_commit).release_tag.object_id).to eq @git.gcommit(linux_v4_1_rc8_commit).release_tag.object_id
				end

				describe "last_official_release_tag" do
					# v3.11     => v3.11
					# v3.11-rc1 => v3.10
					it "should be same as lkp official_release_tag" do
						linux_v3_11_commit = @git.tag('v3.11').commit
						expect(linux_v3_11_commit.last_official_release_tag).to eq 'v3.11'
						expect(linux_v3_11_commit.last_official_release_tag).to eq official_release_tag(linux_v3_11_commit)

						linux_v3_11_rc1_commit = @git.tag('v3.11-rc1').commit
						expect(linux_v3_11_rc1_commit.last_official_release_tag).to eq 'v3.10'
						expect(linux_v3_11_rc1_commit.last_official_release_tag).to eq official_release_tag(linux_v3_11_rc1_commit)
					end
				end

				# v3.11     => v3.10
				# v3.11-rc1 => v3.10
				describe "prev_official_release_tag" do
					it "should be same as lkp prev_official_release_tag" do
						linux_v3_11_commit = @git.tag('v3.11').commit
						expect(linux_v3_11_commit.prev_official_release_tag).to eq 'v3.10'
						expect(linux_v3_11_commit.prev_official_release_tag).to eq prev_official_release_tag(linux_v3_11_commit)

						linux_v3_11_rc1_commit = @git.tag('v3.11-rc1').commit
						expect(linux_v3_11_rc1_commit.prev_official_release_tag).to eq 'v3.10'
						expect(linux_v3_11_rc1_commit.prev_official_release_tag).to eq prev_official_release_tag(linux_v3_11_rc1_commit)
					end
				end

				# v3.12-rc1 => v3.12
				# v3.12     => v3.13
				describe "next_official_release_tag" do
					it "should be same as lkp next_official_release_tag" do
						linux_v3_12_rc1_commit = @git.tag('v3.12-rc1').commit
						expect(linux_v3_12_rc1_commit.next_official_release_tag).to eq 'v3.12'
						expect(linux_v3_12_rc1_commit.next_official_release_tag).to eq next_official_release_tag(linux_v3_12_rc1_commit)

						linux_v3_12_commit = @git.tag('v3.12').commit
						expect(linux_v3_12_commit.next_official_release_tag).to eq 'v3.13'
						expect(linux_v3_12_commit.next_official_release_tag).to eq next_official_release_tag(linux_v3_12_commit)
					end
				end
			end

			describe "base_release_tag" do
				it "should be same as last_linus_release_tag with default arguments" do
					expect(@git.gcommit(linux_v4_1_rc8_commit).base_release_tag).to eq(["v4.1-rc8", true])
					expect(@git.gcommit(linux_v4_1_rc8_commit).base_release_tag).to eq(last_linus_release_tag(linux_v4_1_rc8_commit))

					linux_v2_6_32_commit = @git.tag('v2.6.32').commit
					expect(linux_v2_6_32_commit.base_release_tag).to eq ["v2.6.32", true]
					expect(linux_v2_6_32_commit.base_release_tag).to eq last_linus_release_tag(linux_v2_6_32_commit)


					linux_v2_6_32_child_commit = "03b1320dfceeb093890cdd7433e910dca6225ddb"
					expect(@git.gcommit(linux_v2_6_32_child_commit).base_release_tag).to eq ["v2.6.32-rc8", false]
					expect(@git.gcommit(linux_v2_6_32_child_commit).base_release_tag).to eq last_linus_release_tag(linux_v2_6_32_child_commit)
				end

				it "should cache result" do
					linux_v2_6_32_child_commit = "03b1320dfceeb093890cdd7433e910dca6225ddb"
					expect(@git.gcommit(linux_v2_6_32_child_commit).base_release_tag.object_id).to eq @git.gcommit(linux_v2_6_32_child_commit).base_release_tag.object_id
				end
			end
		end

		describe Git::Base do
			before do
				@git = Git.project_init
			end

			describe "gcommit" do
				it "should cache commits of single git object" do
					gcommit1 = @git.gcommit(linux_v4_1_rc8_commit)
					gcommit2 = @git.gcommit(linux_v4_1_rc8_commit)

					expect(gcommit2.object_id).to eq gcommit1.object_id
					expect(gcommit2.committer.name.object_id).to eq gcommit2.committer.name.object_id
				end

				it "should cache commits of multiple git objects" do
					git1 = Git.project_init
					git2 = Git.project_init

					expect(git2.object_id).not_to eq git1.object_id
					expect(git2.gcommit(linux_v4_1_rc8_commit).object_id).to eq git1.gcommit(linux_v4_1_rc8_commit).object_id
				end
			end

			describe "release_tags_with_order" do
				it "should be same as linus_tags when project is linux/linus" do
					actual = linus_tags
					expect = @git.release_tags_with_order

					expect(expect.count).to be > 0
					expect(expect).to eq actual
				end

				it "should cache result" do
					expect(@git.release_tags_with_order.object_id).to eq @git.release_tags_with_order.object_id
				end
			end

			describe "release_tag_order" do
				it "should be same as tag_order with default parameters" do
					actual = tag_order("v2.6.32-rc8")
					expect = @git.release_tag_order('v2.6.32-rc8')

					expect(expect).to be < 0
					expect(expect).to eq actual
				end
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
		before do
			@git = Git.project_init(project: 'gcc')
		end

		# tag gcc-5_1_0-release
		gcc_5_1_0_release_commit = "d5ad84b309d0d97d3955fb1f62a96fc262df2b76"
		gcc_non_release_commit = "ab2a707c83582b85a20079b53f1c8bc19942f5d1"
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
				gcommit = @git.gcommit(gcc_5_1_0_release_commit)

				expect(gcommit.author.formatted_name).to eq('gccadmin <gccadmin@138bc75d-0d04-0410-961f-82ee72b054a4>')
				expect(gcommit.committer.formatted_name).to eq gcommit.author.formatted_name
				expect(gcommit.subject).to eq("Update ChangeLog and version files for release")
				expect(gcommit.interested_tag).to eq "gcc-5_1_0-release"
				expect(gcommit.parent_shas).to eq(["9a2ae78f8140d02ca684fdbadfe09cbbbfd5c27f"])
				expect(gcommit.committer.name).to eq('gccadmin')
			end

			describe "release_tag" do
				it "should be correct" do
					expect(@git.gcommit(gcc_5_1_0_release_commit).release_tag).to eq 'gcc-5_1_0-release'
					expect(@git.gcommit(gcc_non_release_commit).release_tag).to eq nil
				end
			end

			describe "base_release_tag" do
				it "should be correct" do
					expect(@git.gcommit(gcc_5_1_0_release_commit).base_release_tag).to eq ['gcc-5_1_0-release', true]

					# below commit is at branch gcc-4_9-branch
					gcc_4_9_2_release_commit = @git.tag('gcc-4_9_2-release').commit
					expect(gcc_4_9_2_release_commit.base_release_tag).to eq ['gcc-4_9_2-release', true]

					gcc_4_9_2_release_child_commit = "84a4713962eb632bc75f235566ba1d47690bbf10"
					expect(@git.gcommit(gcc_4_9_2_release_child_commit).base_release_tag).to eq(['gcc-4_9_2-release', false])
				end
			end
		end
	end

end
