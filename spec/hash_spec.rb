require 'spec_helper'
require 'yaml'
require "#{LKP_SRC}/lib/hash.rb"

expects = [
	['create path',
				"{}",
				"1.2.3: 4",
				{"1"=>{"2"=>{"3"=>4}}}
	],
	['add scalar to scalar',
				"a.b.c: 1",
				"a.b.c+: 2",
				{"a"=>{"b"=>{"c"=>[1, 2]}}}
	],
	['add scalar to array',
				"a.b.c: [1, 2]",
				"a.b.c+: 3",
				{"a"=>{"b"=>{"c"=>[1, 2, 3]}}}
	],
	['add scalar to hash',
				"a.b.c: {1: 2}",
				"a.b.c+: 3",
				{"a"=>{"b"=>{"c"=>{1 => 2, 3 => nil}}}}
	],
	['add array to array',
				"a.b.c: [1, 2]",
				"a.b.c+: [3]",
				{"a"=>{"b"=>{"c"=>[1, 2, 3]}}}
	],
	['add hash to hash',
				"a.b.c: {1: 2}",
				"a.b.c+: {3: 4}",
				{"a"=>{"b"=>{"c"=>{1 => 2, 3 => 4}}}}
	],
	['add array to scalar',
				"a.b.c: 1",
				"a.b.c+: [2, 3]",
				{"a"=>{"b"=>{"c"=>[1, 2, 3]}}}
	],
	['add hash to scalar',
				"a.b.c: 1",
				"a.b.c+: {2: 3}",
				{"a"=>{"b"=>{"c"=>{1 => nil, 2 => 3}}}}
	],
	['delete array item',
				"a.b.c: [1, 2]",
				"a.b.c-: 1",
				{"a"=>{"b"=>{"c"=>[2]}}}
	],
	['delete hash item',
				"a.b.c: {1: 2, 3: 4}",
				"a.b.c-: 1",
				{"a"=>{"b"=>{"c"=>{3 => 4}}}}
	],
	['delete last array',
				"a.b.c: [1, 2]",
				"a.b.c-: ",
				{"a"=>{"b"=>nil}}
	],
	['delete last hash',
				"a.b.c: {1: 2, 3: 4}",
				"a.b.c-: ",
				{"a"=>{"b"=>nil}}
	],
	['delete mid hash',
				"a.b.c: {1: 2, 3: 4}",
				"a.b-: ",
				{"a"=>nil}
	],
	['delete top hash',
				"a.b.c: {1: 2, 3: 4}",
				"a-: ",
				{}
	],

	# deal with abnormal cases gracefully
	['empty + empty',
				"",
				"",
				{}
	],
	['empty + create path',
				"",
				"a.b.c: 1",
				{"a"=>{"b"=>{"c"=>1}}}
	],
	['empty + nil',
				"",
				"---",
				{}
	],
	['nil + empty',
				"---",
				"",
				{}
	],
	['nil + create path',
				"---",
				"a.b.c: 1",
				{"a"=>{"b"=>{"c"=>1}}}
	],
	['nil + nil',
				"---",
				"---",
				{}
	],
]

describe "hash lookup/revise:" do
	expects.each do |e|
		it e[0] do
			expect(revise_hash(revise_hash({}, YAML.load(e[1])), YAML.load(e[2]))).to eq e[3]
			expect(revise_hash(YAML.load(e[1]), YAML.load(e[2]))).to eq e[3]
		end
	end
end
