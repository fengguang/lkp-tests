#!/usr/bin/env crystal
require "set"

def common_error_id(line)
  line = line.chomp
  line = line.gsub(/\b[3-9]\.[0-9]+[-a-z0-9.]+/, "#")          # linux version: 3.17.0-next-20141008-g099669ed
  line = line.gsub(/\b[1-9][0-9]-[A-Z][a-z]+-[0-9]{4}\b/, "#") # Date: 28-Dec-2013
  line = line.gsub(/\b0x[0-9a-f]+\b/, "#")                     # hex number
  line = line.gsub(/\b[a-f0-9]{40}\b/, "#")                    # SHA-1
  line = line.gsub(/\b[0-9][0-9.]*/, "#")                      # number
  line = line.gsub(/#x\b/, "0x")
  line = line.gsub(/[\\"$]/, "~")
  line = line.gsub(/[ \t]/, " ")
  line = line.gsub(/\ \ +/, " ")
  line = line.gsub(/([^a-zA-Z0-9])\ /, "\\1")
  line = line.gsub(/\ ([^a-zA-Z])/, "\\1")
  line = line.gsub(/^\ /, "")
  line = line.gsub(/^-/, "")
  line = line.gsub(/\  _/, "_")
  line = line.tr(" ", "-")
  line = line.gsub(/[-_.,;:#!\[(]+$/, "")
  line = line.gsub(/([-_.,;:#!]){3,}/, ":")
  line
end

error_ids = Set(String).new
in_stderr = false
seqno = ""

while (line = STDIN.gets)
  case line
  when /^## ______________([0-9.]+):stderr$/
    in_stderr = true
    seqno = $1
    next
  when /^## ______________#{seqno}:enderr$/
    in_stderr = false
    seqno = ""
  end
  next unless in_stderr
  next unless line.downcase =~ /error|warning/

  error_ids << common_error_id(line)
end

error_ids.each do |id|
  puts id + ": 1"
end
