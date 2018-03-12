#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(__dir__))

require 'git'

module Git
  class Object
    class Commit
      alias orig_initialize initialize

      def initialize(base, sha, init = nil)
        orig_initialize(base, sha, init)
        # this is to convert non sha1 40 such as tag name to corresponding commit sha
        # otherwise Object::AbstractObject uses @base.lib.revparse(@objectish) to get sha
        # which sometimes is not as expected when we give a tag name
        self.objectish = @base.command('rev-list', ['-1', objectish]) unless sha1_40?(objectish)
      end

      def project
        @base.project
      end

      def subject
        message.split("\n").first
      end

      # FIXME: rli9 need a better name, or remove the function if not common
      def name
        interested_tag || sha
      end

      def tags
        @tags ||= @base.lib.tag('--points-at', sha).split
      end

      def parent_shas
        @parent_shas ||= parents.map(&:sha)
      end

      def show(content)
        @base.command_lines('show', "#{sha}:#{content}")
      end

      def interested_tag
        @interested_tag ||= release_tag || tags.first
      end

      def release_tag
        unless @release_tag
          release_tags_with_order = @base.release_tags_with_order
          @release_tag = tags.find { |tag| release_tags_with_order.include? tag }
        end

        @release_tag
      end

      #
      # if commit has a version tag, return it directly
      # otherwise checkout commit and get latest version from Makefile.
      #
      def last_release_tag
        return [release_tag, true] if release_tag

        if project == 'linux' && !@base.project_spec['use_customized_release_tag_pattern']
          @base.linux_last_release_tag_strategy(sha)
        else
          last_release_sha = @base.command("rev-list #{sha} | grep -m1 -Fx \"#{@base.release_shas.join("\n")}\"").chomp

          last_release_sha.empty? ? nil : [@base.release_shas2tags[last_release_sha], false]
        end
      end

      def base_rc_tag
        # rli9 FIXME: bad smell here to distinguish linux by case/when
        commit = case project
                 when 'linux'
                   @base.gcommit("#{sha}~") if committer.name == 'Linus Torvalds'
                 end

        commit ||= self

        tag, _is_exact_match = commit.last_release_tag
        tag
      end

      # v3.11     => v3.11
      # v3.11-rc1 => v3.10
      def last_official_release_tag
        tag, _is_exact_match = last_release_tag
        return tag unless tag =~ /-rc/

        order = @base.release_tag_order(tag)
        tag_with_order = @base.release_tags_with_order.find { |tag, o| o <= order && tag !~ /-rc/ }

        tag_with_order ? tag_with_order[0] : nil
      end

      # v3.11     => v3.10
      # v3.11-rc1 => v3.10
      def prev_official_release_tag
        tag, is_exact_match = last_release_tag

        order = @base.release_tag_order(tag)
        tag_with_order = @base.release_tags_with_order.find do |tag, o|
          next if o > order
          next if o == order && is_exact_match

          tag !~ /-rc/
        end

        tag_with_order ? tag_with_order[0] : nil
      end

      # v3.12-rc1 => v3.12
      # v3.12     => v3.13
      def next_official_release_tag
        tag = release_tag
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

      RE_BY_CC = /(?:by|[Cc][Cc]):\s*([^<\r\n]+) <([^>\r\n]+@[^>\r\n]+)>\s*$/

      def by_cc
        m = message
        pos = 0
        res = []
        while (mat = RE_BY_CC.match(m, pos))
          res.push Git::Author.new("#{mat[1]} <#{mat[2]}> #{Time.now.to_i} ")
          pos = mat.end 0
        end
        res
      end

      def reachable_from?(branch)
        branch = @base.gcommit(branch)
        r = @base.command('rev-list', ['-n', '1', sha, "^#{branch.sha}"])
        r.strip.empty?
      end

      def merged_by
        base = base_rc_tag
        tags = @base.ordered_release_tags.reverse
        tags = tags.drop_while { |tag| tag != base }.drop(1)
        tags.find { |tag| reachable_from?(tag) }
      end
    end

    class Tag
      def commit
        @base.gcommit(@base.command('rev-list', ['-1', @name]))
      end
    end
  end
end
