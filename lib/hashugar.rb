#!/usr/bin/env ruby
#
# https://github.com/jsuchal/hashugar
#
# MIT LICENSE
#
# Copyright (c) 2011 Sven Fuchs <svenfuchs@artweb-design.de>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

class Hashugar
	def initialize(hash)
		@table = {}
		@table_with_original_keys = {}
		hash.each_pair do |key, value|
			hashugar = value.to_hashugar
			@table_with_original_keys[key] = hashugar
			@table[stringify(key)] = hashugar
		end
	end

	def method_missing(method, *args, &block)
		method = method.to_s
		if method.chomp!('=')
			@table[method] = args.first
		else
			@table[method]
		end
	end

	def [](key)
		@table[stringify(key)]
	end

	def []=(key, value)
		@table[stringify(key)] = value
	end

	def respond_to?(key, include_all=false)
		super(key) || @table.has_key?(stringify(key))
	end

	def each(&block)
		@table_with_original_keys.each(&block)
	end

	def to_hash
		hash = @table_with_original_keys.to_hash
		hash.each do |key, value|
			hash[key] = value.to_hash if value.is_a?(Hashugar)
		end
	end

	def empty?
		@table.empty?
	end

	private
	def stringify(key)
		key.is_a?(Symbol) ? key.to_s : key
	end
end

class Hash
	def to_hashugar
		Hashugar.new(self)
	end
end

class Array
	def to_hashugar
		map(&:to_hashugar)
	end
end

class Object
	def to_hashugar
		self
	end
end
