#!/usr/bin/env ruby

Array(___).each do |e|
  raise Job::ParamError, "constraint not satisfied: #{e}" unless eval(e)
end
