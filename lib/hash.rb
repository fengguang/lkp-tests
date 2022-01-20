#!/usr/bin/env ruby

require 'set'

def lookup_hash(hash, path, create_missing = false)
  keys = path.split('.')
  parent = hash
  pkey = keys.first

  loop do
    k = keys.shift
    v = hash[k]
    if create_missing && v.nil?
      v = hash[k] = keys.empty? ? nil : {}
    end
    return parent, pkey, hash, k, keys unless v.is_a?(Hash) && !keys.empty?

    parent = hash
    pkey = k
    hash = v
  end
end

ACCUMULATIVE_KEYS = %w(
    mail_to
    mail_cc
    constraints
).freeze
def accumulative_key?(k)
  return true if ACCUMULATIVE_KEYS.include? k
  return true if k =~ /^need_/ && k !~ /^need_(memory|cpu|modules)$/

  false
end

def merge_accumulative(a, b)
  return a if b.nil?

  case a
  when nil
    a = b
  when Array
    case b
    when Array
      a.concat b
    else
      a << b
    end
  when Hash
    case b
    when Hash
      a.update(b)
    else
      a.update(b => nil)
    end
  else
    case b
    when Array
      a = [a].concat b
    when Hash
      b[a] ||= nil
      a = b
    else
      a = [a, b]
    end
  end

  a
end

# "overwrite_top_keys = true" will have the same semantics with
# original.update(revisions) except for the special *+, *-, a.b.c
# notions and accumulative keys.
def revise_hash(original, revisions, overwrite_top_keys = true)
  # deal with empty YAML files gracefully
  original ||= {}
  revisions ||= {}

  original.merge!(revisions) do |key, oldval, newval|
    if key[-1] == '+' ||
       key[-1] == '-' ||
       accumulative_key?(key)
      merge_accumulative(oldval, newval)
    else
      overwrite_top_keys ? newval : oldval
    end
  end

  org_keys = original.keys.to_set
  rev_keys = revisions.keys.to_set
  all_keys = org_keys + rev_keys

  all_keys.delete_if do |k|
    next true unless k.is_a?(String)

    v = if org_keys.include? k
          original[k]
        else
          revisions[k]
        end
    case k[-1]
    when '-'
      kk = k[0..-2]
      parent, pkey, hash, key, _keys = lookup_hash(original, kk)
      if hash.include? key
        if v
          keys = if v.is_a? Hash
                   v.keys
                 else
                   Array(v)
                 end
          keys.each { |k| hash[key].delete k }
          hash[key] = nil if hash[key].empty?
        else
          hash.delete key
          parent[pkey] = nil if hash.empty? && parent.object_id != hash.object_id
        end
      end
      next false
    when '+'
      kk = k.chomp '+'
      _parent, _pkey, hash, key, _keys = lookup_hash(original, kk, true)
      merge_v = merge_accumulative(hash[key], v)
      merge_v.uniq! if merge_v.instance_of? Array
      hash[key] = merge_v
      next false
    end

    next true unless k.index('.')

    _parent, _pkey, hash, key, _keys = lookup_hash(original, k, true)
    hash[key] = v if overwrite_top_keys || hash.object_id != original.object_id || hash[key].nil?
    next false if hash.object_id != original.object_id

    true
  end

  all_keys.each { |k| original.delete k }

  original
end

def escape_mongo_key(hash)
  h = {}
  hash.each do |k, v|
    case k
    when String
      kk = k
    when Symbol
      kk = ":#{k}"
    end
    h[kk.tr '.', '․'] = v
  end
  h
end

def unescape_mongo_key(hash)
  h = {}
  hash.each do |k, v|
    k = k.tr '․', '.'
    case k
    when /^:(.*)/
      k = $1.to_sym
    end
    h[k] = v
  end
  h
end

def format_print(input_hash, table_header)
  # input:
  #   input_hash:
  #     [{"suite"=>"borrow", "id"=>"crystal.4044913"},
  #      {"suite"=>"fio-basic", "id"=>"crystal.4045343"}]
	#   table_header:
  #     ["id", "suite"]
  # output:
  #       id                suite
  #       crystal.4044913   borrow
  #       crystal.4045343   fio-basic
  if input_hash.empty?
    puts "query input_hash is empty!"
    return
  end

  # collect table header length
  cell_len = []
  table_header.each do |k|
    cell_len << k.length
  end

  # collect table field'value length
  input_hash.each do |result|
    table_header.each_with_index do |field, i|
      cell_len[i] = result[field].to_s.length if result[field].to_s.length > cell_len[i]
    end
  end

  # print table header
  line = ""
  table_header.each_with_index do |field, i|
    line += "#{field}" + " "*(cell_len[i] - field.length + 3)
  end
  puts line

  # print table content
  input_hash.each do |result|
    line = ""
    table_header.each_with_index do |field, i|
      line += "#{result[field].to_s}" + " "*(cell_len[i] - result[field].to_s.length + 3)
    end
    puts line
  end
end
