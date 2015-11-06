#!/usr/bin/env ruby

class String
	def remediate_invalid_byte_sequence(options = {})
		self.clone
		    .force_encoding("UTF-8")
		    .encode("UTF-8", "UTF-8", options.merge(invalid: :replace, undef: :replace))
	end
end