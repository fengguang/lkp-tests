#!/usr/bin/env crystal

while (line = STDIN.gets)
  line.chomp!

  case line
  # Example input:
  #  Load Local HITM                   :          7
  #  Load Remote HITM                  :         11
  #  Load Remote HIT                   :          0
  #  Load Local DRAM                   :         15
  #  Load Remote DRAM                  :         11

  # Example output:
  # HITM.local: 7
  # HITM.remote: 11
  # HIT.remote: 0
  # DRAM.local: 15
  # DRAM.remote: 11
  when / Load Local HITM/
    puts "HITM.local: " + line.split[-1]
  when / Load Remote HITM/
    puts "HITM.remote: " + line.split[-1]
  when / Load Remote HIT/
    puts "HIT.remote: " + line.split[-1]
  when / Load Local DRAM/
    puts "DRAM.local: " + line.split[-1]
  when / Load Remote DRAM/
    puts "DRAM.remote: " + line.split[-1]
  end
end
