#!/usr/bin/env crystal

test_subname = [] of String
test_id = -1
is_begin_of_subtest = false
while (line = STDIN.gets)
  # remove color control info
  line.gsub(/.\[1;(\d+)m|.\[0m/, "")
  case line
  when %r{(pts|system)/(\S+)-[0-9.]+ is not installed}
    item = $2
    puts "#{item}.not_installed: 1"
  when %r{(pts|system)/(\S+)-[0-9.]+}
    test_name = $2
    if line =~ /(pts|system)\/(\S+)-[0-9.]+ \[(?<params>.+)\]/
     params = Regex.match[:params] # "Test: Furmark - Resolution: 800 x 600 - Mode: Windowed"
     test_subname << params.split(" - ") # ["Test: Furmark", "Resolution: 800 x 600", "Mode: Windowed"]
                            .map { |param| param.split(": ").last.gsub(/\s+/, "") } # ["Furmark", "800x600", "Windowed"]
                            .join(".")                                              # "Furmark.800x600.Windowed"
    end
    is_begin_of_subtest = true
  when /Average: ([0-9.]+) (.*)/
    value = $1
    unit = $2
    if is_begin_of_subtest
      test_id += 1
      is_begin_of_subtest = false
    end
    unit = unit.downcase.tr(" ", "_").tr("/", "_")
    if !test_subname.empty?
      puts "#{test_name}.#{test_subname.at(test_id)}.#{unit}: #{value}"
    else
      puts "#{test_name}.#{test_id}.#{unit}: #{value}"
    end
  when /Final: ([0-9.]+) (.*)/
    value = $1
    if value == "1" && is_begin_of_subtest
      test_id += 1
      is_begin_of_subtest = false
    end
    if !test_subname.empty?
      puts "#{test_name}.#{test_subname.at(test_id)}.Final: #{value}"
    else
      puts "#{test_name}.#{test_id}.Final: #{value}"
    end
  when /The following tests failed to properly run:/
    puts "#{test_name}.fail: 1"
  when /idle-([0-9.]+)seconds/
    # idle-1.1.0.seconds: 36.055191180
    puts line
  when /smart-([0-9.]+)seconds/
    # smart-1.0.0.seconds: 7.252623981
    puts line
  end
end
