
LKP_SRC ||= ENV["LKP_SRC"]

def puts_err(*messages)
	$stderr.puts "#{File.basename $PROGRAM_NAME}: #{messages.join ' '}"
end
