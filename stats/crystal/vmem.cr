#!/usr/bin/env crystal


require "../../lib/string_ext"

stats = [] of String
test_item = ""
build_type = ""

#vmmalloc_memalign/TEST1: SETUP (check/nondebug)
while (line = STDIN.gets)
  line = line.to_s
  line = line.remediate_invalid_byte_sequence() unless line.valid_encoding?
  case line
  when %r{^(.+)/TEST[0-9]+: SETUP \(.+/(.+)\)$}
    test_item = $1
    build_type = $2
  when %r{^(.+)/(TEST[0-9]+): (PASS|FAIL|SKIP)}
    item = $1
    name = $2
    next unless test_item == item

    stats << item + "_" + name + "_" + build_type + "." + $3.downcase + ": 1"
  when %r{RUNTESTS: stopping: (.+)/(TEST[0-9]+) failed}
    item = $1
    name = $2

    next unless test_item == item

    stats << item + "_" + name + "_" + build_type + ".fail: 1"
  when %r{RUNTESTS: stopping: (.+)/(TEST[0-9]+) timed out}
    item = $1
    name = $2
    next unless test_item == item

    stats << item + "_" + name + "_" + build_type + ".timeout: 1"
  when %r{^(.+)/(TEST[0-9]+): SKIP}
    item = $1
    name = $2
    stats << item + "_" + name + ".test_skip: 1"
  end
end

stats.uniq.each { |stat| puts stat }
