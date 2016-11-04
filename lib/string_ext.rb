#!/usr/bin/env ruby

REGEX_ANSI_COLOR = /\e\[([0-9;]+m|[mK])/

class String

	# for converting log lines into "Content-Type: text/plain;" emails
	def plain_text
		self.gsub(REGEX_ANSI_COLOR, '').
		     tr("\r", "\n").
		     gsub(/[^[:print:]\n]/, '')
	end

	def remediate_invalid_byte_sequence(options = {})
		self.clone
		    .force_encoding("UTF-8")
		    .encode("UTF-8", "UTF-8", options.merge(invalid: :replace, undef: :replace))
	end

	def replace_invalid_utf8!(to = '_')
		return self if valid_encoding?
		self.encode!("UTF-8", "UTF-8", { invalid: :replace, undef: :replace, replace: to })
	end

	def strip_nonprintable_characters()
		self.gsub(/[^[:print:]]/, '')
	end
end
