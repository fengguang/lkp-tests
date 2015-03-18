# common utilities

def deepcopy(o)
	Marshal.load(Marshal.dump(o))
end
