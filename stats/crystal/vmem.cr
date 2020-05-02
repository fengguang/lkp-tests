#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require "#{LKP_SRC}/lib/string_ext"

stats = []
test_item = ""
build_type = ""

#vmmalloc_memalign/TEST1: SETUP (check/nondebug)
while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
  case line
  when %r{^(.+)/TEST[0-9]+: SETUP \(.+/(.+)\)$}
    test_item = Regexp.last_match[1]
    build_type = Regexp.last_match[2]
  when %r{^(.+)/(TEST[0-9]+): (PASS|FAIL|SKIP)}
    item = Regexp.last_match[1]
    name = Regexp.last_match[2]
    next unless test_item == item

    stats << item + "_" + name + "_" + build_type + "." + Regexp.last_match[3].downcase + ": 1"
  when %r{RUNTESTS: stopping: (.+)/(TEST[0-9]+) failed}
    item = Regexp.last_match[1]
    name = Regexp.last_match[2]

    next unless test_item == item

    stats << item + "_" + name + "_" + build_type + ".fail: 1"
  when %r{RUNTESTS: stopping: (.+)/(TEST[0-9]+) timed out}
    item = Regexp.last_match[1]
    name = Regexp.last_match[2]
    next unless test_item == item

    stats << item + "_" + name + "_" + build_type + ".timeout: 1"
  when %r{^(.+)/(TEST[0-9]+): SKIP}
    item = Regexp.last_match[1]
    name = Regexp.last_match[2]
    stats << item + "_" + name + ".test_skip: 1"
  end
end

stats.uniq.each { |stat| puts stat }
