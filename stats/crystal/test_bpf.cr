#!/usr/bin/env crystal


require "../../lib/string_ext"

stats = [] of String
success_test = 0
fail_test = 0
is_divided = false
type = ""

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?

  case line
  when /test_bpf: #[0-9]+ (.+) jited:.+ PASS$/
    type = $1.tr(" ", "_")
    stats << type + ".pass: 1"
  when /test_bpf: #[0-9]+ (.+) jited:.+ FAIL/
    type = $1.tr(" ", "_")
    stats << type + ".fail: 1"
  when /test_bpf: #[0-9]+ check: (.+) PASS$/
    type = $1.tr(" ", "_")
    stats << "check:_" + type + ".pass: 1"
  when /test_bpf: #[0-9]+ check: (.+) FAIL/
    type = $1.tr(" ", "_")
    stats << "check:_" + type + ".fail: 1"
  when /test_bpf: #[0-9]+ (.+) PASS$/
    type = $1.tr(" ", "_")
    stats << type + ".pass: 1"
  when /test_bpf: #[0-9]+ (.+) FAIL/
    type = $1.tr(" ", "_")
    stats << type + ".fail: 1"
  when /test_bpf: #[0-9]+ check: (.+)/
    type = "check:_" + $1.strip.tr(" ", "_")
    is_divided = true
  when /test_bpf: #[0-9]+ (.+)/
    type = $1.strip.tr(" ", "_")
    is_divided = true
  when /test_bpf: Summary: ([0-9]+) PASSED, ([0-9]+) FAILED, \[.+ JIT'ed\]$/
    success_test = $1
    fail_test = $2
  when /(PASS|FAIL)/
    if is_divided
	    stats << type + ".#{$1.downcase}: 1"
      is_divided = false
    end
  end
end

stats.each { |stat| puts stat }
puts "success_test: #{success_test}"
puts "fail_test: #{fail_test}"
