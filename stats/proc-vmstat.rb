# input: each line of test log with Array(String) structure which like:
#   [
#     "time: 1600586885",
#     "nr_free_pages 87512",
#     ...
#     "time: 1600586886",
#     "nr_free_pages 87787",
#     ...
#   ]
# return eg:
#   {
#     "time"=>[1600586885, 1600586886],
#     "nr_free_pages"=>[87512, 87787],
#     ...
#   }
def proc_vmstat(log_lines)
  result = Hash.new { |hash, key| hash[key] = [] }
  log_lines.each do |line|
    key, value = line.split(/:?\s+/)
    result[key] << value.to_i
  end

  result
end
