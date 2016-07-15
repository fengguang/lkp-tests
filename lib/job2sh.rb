#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC']
require "#{LKP_SRC}/lib/job.rb"
require 'shellwords'

TMP ||= ENV['TMP'] || '/tmp'

SHELL_BLOCK_KEYWORDS = {
	'if'		=> [ 'then', 'fi' ],
	'for'		=> [ 'do', 'done' ],
	'while'		=> [ 'do', 'done' ],
	'until'		=> [ 'do', 'done' ],
	'function'	=> [ '{', '}' ],
}

def valid_shell_variable?(key)
	key =~ /^[a-zA-Z_]+[a-zA-Z0-9_]*$/
end

def shell_encode_keyword(key)
	key.gsub(/[^a-z0-9_]/) { |m| '_' + m.getbyte(0).to_s + '_' }
end

def shell_escape_expand(val)
	val = val.join "\n" if Array === val

	case val
	when nil, ''
		return ''
	when Fixnum
		return val.to_s
	when /^[-a-zA-Z0-9~!@#%^&*()_+=;:.,<>\/?|\t "]+$/, Time
		return "'#{val}'"
	when /^[-a-zA-Z0-9~!@#%^&*()_+=;:.,<>\/?|\t '$]+$/
		return '"' + val + '"'
	else
		return Shellwords.shellescape(val)
	end
end

def get_program_env(program, env)
	program_env = {}
	args = []

	if env == nil
		return program_env, args
	end

	case env
	when String
		args = Shellwords.shellsplit(env).map { |s| shell_escape_expand(s) }
	when Fixnum, Float
		args = env.to_s
	when Hash
		env.each { |k, v|
			case v
			when Hash
				v.each { |kk, vv|
				program_env[kk] = vv
				}
			else
				program_env[k] = v
			end
		}
	end

	return program_env, args
end

def read_param_map_rules(file)
	lines = File.read file
	rules = {}
	prev_rule = nil
	head = nil
	loop do
		head, rule, lines = lines.partition /^\/(.*?[^\\])\/\s+/
		head.chomp!
		rules[prev_rule] = head if prev_rule
		break if rule.empty?
		prev_rule = Regexp.new $1
	end
	rules[prev_rule] = head if prev_rule
	rules
end

def replace_symbol_keys(hash)
	return hash unless Hash === hash
	sh = {}
	hash.each do |k, v|
		sh[k.to_s] = v
	end
	sh
end

class Job2sh < Job

	def out_line(line = nil)
		if line == nil
			return if @script_lines[-1] == nil
			return if @script_lines[-1] =~ /^[\s{]*$/
			return if @script_lines[-1] =~ /^\s*(then|do)$/
		end
		@script_lines << line
	end

	def exec_line(line = nil)
		out_line line if @cur_func == :run_job
	end

	def indent(ancestors)
		"\t" * (@cur_func == :extract_stats ? 1 : 1 + ancestors.size)
	end

	def shell_header
		out_line "#!/bin/sh"
		out_line
	end

	def shell_export_env(tabs, key, val)
		exec_line tabs + "export #{key}=" + shell_escape_expand(val)
	end

	def shell_run_program(tabs, program, env)
		program_env, args = get_program_env(program, env)

		cmd = create_cmd(program, args)
		cmd_str = cmd.join ' '
		cmd_str.gsub!(LKP_SRC, '$LKP_SRC')
		cmd_str.gsub!(TMP, '$TMP')

		program_env.each { |k, v|
			exec_line tabs + 'export ' + shell_encode_keyword(k) + "=" + shell_escape_expand(v)
		}
		out_line tabs + cmd_str
		program_env.each { |k, v|
			exec_line tabs + 'unset ' + shell_encode_keyword(k)
		}
	end

	def create_cmd(program, args)
		program_path = @programs[program] || program

		args = [] if program_path.index('/stats/')
		program_dir = File.dirname(program_path)
		wrapper = program_dir + '/wrapper'
		if File.executable?(wrapper)
			cmd = [ wrapper, program, *args ]
		else
			cmd = [ program_path, *args ]
		end

		case program_dir
		when %r{/monitors}
			cmd = [ "run_monitor", *cmd ]
			exec_line unless @script_lines[-1] =~ /run_monitor/
		when %r{/setup$}
			cmd = [ "run_setup", *cmd ]
			exec_line
		when %r{/daemon$}
			cmd = [ "start_daemon", *cmd ]
			exec_line
		when %r{/tests$}
			cmd = [ "run_test", *cmd ]
			exec_line
			@stats_lines << "\t$LKP_SRC/stats/wrapper time #{program}.time"
		else
			exec_line
		end

		return cmd
	end

	def parse_one(ancestors, key, val, pass)
		tabs = indent(ancestors)
		if @programs.include?(key) or (key =~ /^(call|command|source)\s/ and @cur_func == :run_job)
			return false unless pass == :PASS_RUN_COMMANDS
			shell_run_program(tabs, key.sub(/^call\s+/, '').sub(/^source\s+/, '.'), val)
			return :action_call_command
		elsif String === val and key =~ %r{^script\s+(monitors|setup|tests|daemon|stats)/([-a-zA-Z0-9_/]+)$}
			return false unless pass == :PASS_NEW_SCRIPT
			script_file = $1 + '/' + $2
			script_name = File.basename $2
			if @cur_func == :run_job	and script_file =~ %r{^(monitors|setup|tests|daemon)/} or
			   @cur_func == :extract_stats	and script_file.index('stats/') == 0
				@programs[script_name] = LKP_SRC + '/' + script_file
			end
			exec_line
			exec_line tabs + "cat > $LKP_SRC/#{script_file} <<'EOF'"
			exec_line val
			exec_line 'EOF'
			exec_line tabs + "chmod +x $LKP_SRC/#{script_file}"
			exec_line
			return :action_new_script
		elsif String === val and key =~ /^(function)\s+([a-zA-Z_]+[a-zA-Z_0-9]*)$/
			return false unless pass == :PASS_NEW_SCRIPT
			shell_block = $1
			func_name = $2
			exec_line
			exec_line tabs + "#{func_name}()"
			exec_line tabs + SHELL_BLOCK_KEYWORDS[shell_block][0]
			val.each_line { |l|
				exec_line "\t" + tabs + l
			}
			exec_line tabs + SHELL_BLOCK_KEYWORDS[shell_block][1]
			return :action_new_function
		elsif Hash === val and key =~ /^(if|for|while|until)\s/
			return false unless pass == :PASS_RUN_COMMANDS
			shell_block = $1
			exec_line
			exec_line tabs + "#{key}"
			exec_line tabs + SHELL_BLOCK_KEYWORDS[shell_block][0]
			parse_hash(ancestors + [key], val)
			exec_line tabs + SHELL_BLOCK_KEYWORDS[shell_block][1]
			return :action_control_block
		elsif Hash === val
			return false unless pass == :PASS_RUN_COMMANDS
			exec_line
			func_name = key.tr('^a-zA-Z0-9_', '_')
			exec_line tabs + "#{func_name}()"
			exec_line tabs + "{"
			parse_hash(ancestors + [key], val)
			exec_line tabs + "}\n"
			exec_line tabs + "#{func_name} &"
			return :action_background_function
		elsif valid_shell_variable?(key)
			return false unless pass == :PASS_EXPORT_ENV
			shell_export_env(tabs, key, val)
			return :action_export_env
		end
		return nil
	end

	def parse_hash(ancestors, hash)
		nr_bg = 0
		hash.each { |key, val| parse_one(ancestors, key, val, :PASS_EXPORT_ENV) }
		hash.each { |key, val| parse_one(ancestors, key, val, :PASS_NEW_SCRIPT) }
		hash.each { |key, val| parse_one(ancestors, key, val, :PASS_RUN_COMMANDS) == :action_background_function and nr_bg += 1 }
		if nr_bg > 0
			exec_line
			exec_line indent(ancestors) + "wait"
		end
	end

	def to_shell
		@script_lines = []
		@stats_lines = []

		shell_header

		@cur_func = :run_job

		out_line "export_top_env()"
		out_line "{"
		@programs = available_programs(:workload_and_monitors)
		job = (@jobx||@job).clone # a shallow copy so that delete_if won't impact @job
		job.delete_if { |key, val| parse_one([], key, val, :PASS_EXPORT_ENV) }
		out_line
		out_line "\t[ -n \"$LKP_SRC\" ] ||"
		out_line "\texport LKP_SRC=/lkp/${user:-lkp}/src"
		out_line "}\n\n"

		out_line "run_job()"
		out_line "{"
		out_line
		out_line "\techo $$ > $TMP/run-job.pid"
		out_line
		out_line "\t. $LKP_SRC/lib/job.sh"
		out_line "\t. $LKP_SRC/lib/env.sh"
		out_line
		out_line "\texport_top_env"
		out_line
		parse_hash [], job
		out_line "}\n\n"

		@cur_func = :extract_stats
		out_line "extract_stats()"
		out_line "{"
		@programs = available_programs(:stats)
		parse_hash [], job
		out_line
		out_line @stats_lines
		parse_hash [], YAML.load_file(LKP_SRC + '/etc/default_stats.yaml')
		out_line "}\n\n"

		out_line '"$@"'

		@script_lines
	end

	def param_files
		maps = {}
		ruby_scripts = {}
		Dir["#{lkp_src}/params/*"].map do |f|
			name = File.basename f
			case name
			when /(.*)\.rb$/
				ruby_scripts[$1] = f
			else
				maps[name] = f
			end
		end
		[maps, ruby_scripts]
	end

	def map_param(hash, key, val, rule_file)
		return unless String === val
		___ = val.dup # for reference by expressions
		output = nil
		rules = read_param_map_rules(rule_file)
		rules.each do |pattern, expression|
			val.sub!(pattern) do |s|
				# puts s, pattern, expression
				o = eval(expression)
				case output
				when nil
					output = o
				when Hash
					output.merge! o
				else
					$stderr.puts "confused while mapping param: #{___}"
					break 2
				end
				nil
			end
		end
		hash[key] = replace_symbol_keys(output) if output
	end

	def expand_params
		@jobx = deepcopy @job
		maps, ruby_scripts = param_files
		for_each_in(@jobx, maps.keys.to_set) { |pk, h, k, v|
			map_param(h, k, v, maps[k])
		}
		for_each_in(@jobx, ruby_scripts.keys.to_set) { |pk, h, k, v|
			evaluate_param(h, k, v, ruby_scripts[k])
		}
	end
end
