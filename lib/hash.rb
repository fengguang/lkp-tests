#!/usr/bin/env ruby

def lookup_hash(hash, path, create_missing = false)
	keys = path.split('.')
	parent = hash
	pkey = keys.first

	loop do
		k = keys.shift
		v = hash[k]
		if create_missing and v == nil
			v = hash[k] = keys.empty? ? nil : Hash.new
		end
		if Hash === v and not keys.empty?
			parent = hash
			pkey = k
			hash = v
			next
		else
			return parent, pkey, hash, k, keys
		end
	end
end

def revise_hash(original, revisions)
	# deal with empty YAML files gracefully
	original ||= {}
	revisions ||= {}

	rev_keys = revisions.keys
	rev_keys.delete_if do |k|
		v = revisions[k]
		if k[-1] == '-'
			kk = k[0..-2]
			parent, pkey, hash, key, keys = lookup_hash(original, kk)
			if hash.include? key
				if v
					hash[key].delete v
				else
					hash.delete key
					if hash.empty? and parent.object_id != hash.object_id
						parent[pkey] = nil
					end
				end
			end
			next false
		elsif k[-1] == '+'
			kk = k[0..-2]
			parent, pkey, hash, key, keys = lookup_hash(original, kk, true)
			case hash[key]
			when nil
				hash[key] = v
			when Array
				case v
				when Array
					hash[key].concat v
				else
					hash[key] << v
				end
			when Hash
				case v
				when Hash
					hash[key].update(v)
				else
					hash[key].update({ v => nil })
				end
			else
				case v
				when Array
					hash[key] = [ hash[key] ].concat v
				when Hash
					v[hash[key]] ||= nil
					hash[key] = v
				else
					hash[key] = [ hash[key], v ]
				end
			end
			next false
		end

		parent, pkey, hash, key, keys = lookup_hash(original, k, true)
		hash[key] = v
		if hash.object_id != original.object_id
			next false
		else
			next true
		end
	end

	if revisions.object_id == original.object_id
		rev_keys.each { |k| original.delete k }
	end

	original
end
