def time(method, *args)
	start_time = Time.now
	ret = send(method, *args)
	puts "#{(Time.now - start_time).round(1)}s on invoking #{method}, #{args}"

	return ret
end
