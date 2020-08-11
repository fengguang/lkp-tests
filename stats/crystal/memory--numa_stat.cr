#!/usr/bin/env crystal

# time: 123456
# cgroup: pmbench.1
# total=66 N0=0 N1=108 N2=0 N3=0

def parse
  cg = "nocg"
  STDIN.each_line do |line|
    case line
    when /^time:/
      puts line
    when /^cgroup: (\S+)/
      cg = $1
    when /=/
      line_list = line.split
      # item0, *ritems = line.split
      item0 = line_list.shift
      ritems = line_list
      k, v = item0.split '='
      puts "#{cg}.#{k}: #{v}"
      ritems.each do |item|
        sk, sv = item.split '='
        puts "#{cg}.#{k}.#{sk}: #{sv}"
      end
    end
  end
end

parse
