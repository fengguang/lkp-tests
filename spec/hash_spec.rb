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
	['delete array items',
				"a.b.c: [1, 2, 3]",
				"a.b.c-: [1, 2]",
				{"a"=>{"b"=>{"c"=>[3]}}}
	],
	['delete hash item',
				"a.b.c: {1: 2, 3: 4}",
				"a.b.c-: 1",
				{"a"=>{"b"=>{"c"=>{3 => 4}}}}
	],
	['delete hash items',
				"a.b.c: {1: 2, 3: 4}",
				"a.b.c-: [1, 3]",
				{"a"=>{"b"=>{"c"=>nil}}}
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

	['normal hash merge',
				"a:\n  b: 1\nc: 2",
				"a:\n  b: [3, 4]\nd: 5",
				{"a"=>{"b"=>[3, 4]}, "c"=>2, "d"=>5}
	],
	['accumulative key',
				"mail_cc: XXX",
				"mail_cc: YYY",
				{"mail_cc"=>["XXX", "YYY"]}
	],
	['double add array',
				"a+: 1",
				"a+: [2, 3]",
				{"a"=>[1, 2, 3]}
	],
	['double add hash',
				"a+: 1",
				"a+: {2: 3}",
				{"a"=>{1=>nil, 2=>3}}
	],
	['double delete array',
				"a: [1, 2, 3]\na-: 1",
				"a-: [2]",
				{"a"=>[3]}
	],
	['double delete hash',
				"a: {b: 1, c: 2, d: 3}\na-: b",
				"a-: [c]",
				{"a"=>{"d"=>3}}
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
