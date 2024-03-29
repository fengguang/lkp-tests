#!/usr/bin/env crystal

tcp_key = %w(kbps_in kbps_out rcv_s snd_s)
udp_key = %w(kbps_in kbps_out rcv_s snd_s loss ooo LOST)
while (line = STDIN.gets)
  case line
  when /^\s*\d\s*avg\s*\d/
    data = line.split
    data[3..].each_with_index do |v, i|
      puts "tcp.avg." + tcp_key[i] + ": " + v.to_f.to_s
    end
  when /^\s*\d\s*\d\s*\d\s*avg\s*\d/
    data = line.split
    data[5..].each_with_index do |v, i|
      puts "udp.avg." + udp_key[i] + ": " + v.to_f.to_s
    end
  end
end
