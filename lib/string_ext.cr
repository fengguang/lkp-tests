#!/usr/bin/env crystal

REGEX_ANSI_COLOR = /\e\[([0-9;]+m|[mK])/.freeze

class String
  # for converting log lines into "Content-Type: text/plain;" emails
  def plain_text
    gsub(REGEX_ANSI_COLOR, "")
      .tr("\r", "\n")
      .gsub(/[^[:print:]\n]/, "")
  end

  def remediate_invalid_byte_sequence(replace = "")
    clone
      .encode("UTF-8")
  end

  def replace_invalid_utf8!(to = "_")
    return self if valid_encoding?

    encode!("UTF-8", "UTF-8", invalid: :replace, undef: :replace, replace: to)
  end

  def strip_nonprintable_characters
    gsub(/[^[:print:]]/, "")
  end

  def numeric?
    !Float(self).nil?
  rescue StandardError
    false
  end
end
