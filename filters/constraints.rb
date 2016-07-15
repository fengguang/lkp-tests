#!/usr/bin/env ruby

Array(___).each do |e|
	unless eval(e)
		raise Job::ParamError, "constraint not satisfied: #{e}"
	end
end
