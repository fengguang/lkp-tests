#!/usr/bin/env crystal

# time: 123456
# cgroup: pmbench.1
# cache 0

def parse
  cg = "nocg"
  STDIN.each_line do |line|
    case line
    when /^time:/
      puts line
    when /^cgroup: (\S+)/
      cg = $1
    when /(\S+)\s*(\S+)/
      k, v = line.split
      puts "#{cg}.#{k}: #{v}"
    end
  end
end

parse
