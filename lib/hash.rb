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
    mail_cc
    mail_to
    build_success_mail_cc
    constraints
).freeze
def is_accumulative_key(k)
  return true if ACCUMULATIVE_KEYS.include? k
  return true if k =~ /^need_/
  false
end

def merge_accumulative(a, b)
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
       is_accumulative_key(key)
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
    if k[-1] == '-'
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
    elsif k[-1] == '+'
      kk = k.chomp '+'
      _parent, _pkey, hash, key, _keys = lookup_hash(original, kk, true)
      hash[key] = merge_accumulative(hash[key], v)
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
      kk = ':' + k.to_s
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
