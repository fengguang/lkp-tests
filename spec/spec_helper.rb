require 'rspec'

$LOAD_PATH.delete_if {|p| File.expand_path(p) == File.expand_path("./lib")}

LKP_SRC ||= ENV['LKP_SRC']
