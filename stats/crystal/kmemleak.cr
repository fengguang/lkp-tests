#!/usr/bin/env crystal

LKP_SRC     = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath(__FILE__)))
RESULT_ROOT = ENV["RESULT_ROOT"]

memleaks = [] of Hash(String, String)
memleak = {} of String => String
bts = ""

while (line = STDIN.gets)
  case line
  when /^unreferenced object/ # unreferenced object 0xffff9375a9b84e00 (size 128):
    if !bts.empty? && memleak["type"]
      memleak["bt"] = bts
      memleaks << memleak
    end
    bts = ""
    memleak["type"] = "unreferenced_object"
  when /comm "(.*)"/ # comm "swapper/0", pid 1, jiffies 4294667990 (age 37.508s)
    memleak["comm"] = $1
    #    [<(____ptrval____)>] unpack_to_rootfs+0x3d/0x304
    #    [<(____ptrval____)>] populate_rootfs+0x19/0x106
  when /\[.*\] (.*)\+/
    bts = ".#{$1}#{bts}"
  end
end

if !bts.empty? && memleak["type"]
  memleak["bt"] = bts
  memleaks << memleak
end

memleaks.uniq.each { |m| puts "#{m["comm"]}.#{m["type"]}#{m["bt"]}: 1" }
