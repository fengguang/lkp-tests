require 'rspec'

# a hack to append customised path to the end due to several name duplications
# of lib files, like yaml.rb, time.rb
$LOAD_PATH.concat($LOAD_PATH.shift(3))

require 'commit'

describe Commit do
	context "linux" do
		# tag v4.1-rc8
		linux_v4_1_rc8_commit = "0f57d86787d8b1076ea8f9cbdddda2a46d534a27"
		linux_non_release_commit = "b86a7563ca617aa49dfd6b836da4dd0351fe2acc"

		describe "open" do
			before do
				@git = Git.project_init
			end

			it "should work" do
				commit = described_class.open(linux_v4_1_rc8_commit)

				expect(commit).to be_an_instance_of described_class

				expect(commit.to_s).to eq linux_v4_1_rc8_commit
				expect(commit.subject).to eq "Linux 4.1-rc8"
				expect(commit.committer_date.to_s).to eq '2015-06-15 09:51:10 +0800'

				#expect(commit.last_release_tag).to eq ["v4.1-rc8", true]
				#expect(commit.last_release_tag).to eq commit.base_tag
			end

			it "should cache commit" do
				expect(described_class.open(linux_v4_1_rc8_commit).object_id).to eq described_class.open(linux_v4_1_rc8_commit).object_id
			end
		end
	end
end