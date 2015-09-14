LKP_SRC ||= ENV["LKP_SRC"] || File.dirname(File.dirname File.realpath $PROGRAM_NAME)

require "#{LKP_SRC}/lib/simple_cache_method"
require 'git'

module Git
	class Object
		class Commit
			include SimpleCacheMethod

			alias_method :orig_initialize, :initialize
			def initialize(base, sha, init = nil)
				orig_initialize(base, sha, init)
				# this is to convert non sha1 40 such as tag name to corresponding commit sha
				# otherwise Object::AbstractObject uses @base.lib.revparse(@objectish) to get sha
				# which sometimes is not as expected when we give a tag name
				self.objectish = @base.lib.command('rev-list', ['-1', self.objectish]) unless Git.sha1_40?(self.objectish)
			end

			def project
				@base.project
			end

			def subject
				self.message.split("\n").first
			end

			# FIXME rli9 need a better name, or remove the function if not common
			def name
				interested_tag || self.sha
			end

			def tags
				@tags ||= @base.lib.tag('--points-at', self.sha).split
			end

			def parent_shas
				@parent_shas ||= self.parents.map {|commit| commit.sha}
			end

			def show(content)
				@base.lib.command_lines('show', "#{self.sha}:#{content}")
			end

			def interested_tag
				@interested_tag ||= release_tag || tags.first
			end

			def release_tag
				unless @release_tag
					release_tags_with_order = @base.release_tags_with_order
					@release_tag = tags.find {|tag| release_tags_with_order.include? tag}
				end
				@release_tag
			end

			#
			# if commit has a version tag, return it directly
			# otherwise checkout commit and get latest version from Makefile.
			#
			def last_release_tag
				return [release_tag, true] if release_tag

				case @base.project
				when 'linux'
					Git.linux_last_release_tag_strategy(@base, self.sha)
				else
					last_release_sha = @base.lib.command("rev-list --first-parent #{self.sha} | grep -m1 -Fx \"#{@base.release_shas.join("\n")}\"").chomp

					last_release_sha.empty? ? nil : [@base.release_shas2tags[last_release_sha], false]
				end
			end

			# v3.11     => v3.11
			# v3.11-rc1 => v3.10
			def last_official_release_tag
				tag, is_exact_match = self.last_release_tag
				return tag unless tag =~ /-rc/

				order = @base.release_tag_order(tag)
				tag_with_order = @base.release_tags_with_order.find {|tag, o| o <= order && tag !~ /-rc/}

				tag_with_order ? tag_with_order[0] : nil
			end

			# v3.11     => v3.10
			# v3.11-rc1 => v3.10
			def prev_official_release_tag
				tag, is_exact_match = self.last_release_tag

				order = @base.release_tag_order(tag)
				tag_with_order = @base.release_tags_with_order.find do |tag, o|
					next if o > order
					next if o == order and is_exact_match

					tag !~ /-rc/
				end

				tag_with_order ? tag_with_order[0] : nil
			end

			# v3.12-rc1 => v3.12
			# v3.12     => v3.13
			def next_official_release_tag
				tag = self.release_tag
				return nil unless tag

				order = @base.release_tag_order(tag)
				@base.release_tags_with_order.reverse_each do |tag, o|
					next if o <= order

					return tag unless tag =~ /-rc/
				end

				nil
			end

			def version_tag
				tag, is_exact_match = last_release_tag

				tag += '+' if tag && !is_exact_match
				tag
			end

			cache_method :last_release_tag, ->(obj) {obj.to_s}
		end

		class Tag
			def commit
				@base.gcommit(@base.lib.command('rev-list', ['-1', @name]))
			end
		end
	end
end