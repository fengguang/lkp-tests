require 'rspec'

# a hack to append customised path to the end due to several name duplications
# of lib files, like yaml.rb, time.rb
$LOAD_PATH.concat($LOAD_PATH.shift(3))

ENV['LKP_SRC'] = File.expand_path "#{File.dirname(__FILE__)}/.."

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
				commit = Commit.open(linux_v4_1_rc8_commit)

				expect(commit.to_s).to eq linux_v4_1_rc8_commit
			end

			it "should cache commit" do
				expect(Commit.open(linux_v4_1_rc8_commit).object_id).to eq Commit.open(linux_v4_1_rc8_commit).object_id
			end
		end
	end
end