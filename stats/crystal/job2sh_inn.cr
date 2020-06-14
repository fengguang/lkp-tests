require "./job"
require "../../lib/shellwords"

SHELL_BLOCK_KEYWORDS = {
  "if" => %w[then fi],
  "for" => %w[do done],
  "while" => %w[do done],
  "until" => %w[do done],
  "function" => ["{", "}"],
}

def valid_shell_variable?(key)
    key =~ /^[a-zA-Z_]+[a-zA-Z0-9_]*$/
end

def shell_encode_keyword(key)
    key.gsub(/[^a-z0-9_]/) { |m| "_" + m[0].to_s + "_" }
end

def shell_escape_expand(val)
    val = val.join "\n" if val.is_a?(Array)

    case val
    when Nil, ""
        return ""
    when Int32 | Int64 | Float64
        return val.to_s
    when Time
        return "'#{val}'"
    when /^[-a-zA-Z0-9~!@#%^&*()_+=;:.,<>\/?|\t\n "]+$/
        return "'#{val}'"
    when /^[-a-zA-Z0-9~!@#%^&*()_+=;:.,<>\/?|\t\n '$]+$/
        return "\"#{val}\""
    else
        return Shellwords.shellescape(val)
    end
end

class Job2sh < Job
    def initialize
        super
        @script_lines = Array(String).new
        @stats_lines = Array(String).new
        @cur_func = :run_job

        @monitors = Hash(String, String).new
        @setups = Hash(String, String).new
    end

    def exec_line(line = nil)
        out_line line if @cur_func == :run_job
    end

    def indent(ancestors)
        "\t" * (@cur_func == :extract_stats ? 1 : 1 + ancestors.size)
    end

    def get_program_env(_program, env : YAML::Any)
        env.as_nil
        return get_program_env(_program, nil)

        rescue exception
            env = env.as_i? || env.as_f? || env.as_s? || env.as_h? # what else type?
            return get_program_env(_program, env)
    end

    def get_program_env(_program, env)
        program_env = Hash(String, Int32 | String).new
        args = Array(String).new
        return program_env, args if @cur_func == :extract_stats

        case env
        when Int32, Int64, Float64
            args << env.to_s
        when String
            args = Shellwords.shellsplit(env).map { |s| shell_escape_expand(s) }
        when Hash
            env.each do |k, v|
                case v
                when Hash
                    v.each do |kk, vv|
                        program_env[kk.to_s] = vv
                    end
                else
                    if v.is_a?(Int32)
                        program_env[k.to_s] = v
                    elsif v.is_a?(String)
                        program_env[k.to_s] = v
                    else
                        program_env[k.to_s] = v.as_i if v.as_i?
                        program_env[k.to_s] = v.as_s if v.as_s?
                    end
                end
            end
        else
            puts "<#{__FILE__}:>: need fix (#{env}@#{env.class})"
        end

        return program_env, args
    end

    def combine_cmd(program_path, program, args)
        program_dir = File.dirname(program_path.to_s)
        wrapper = program_dir + "/wrapper"
        if File.executable?(wrapper)
            cmd_first = wrapper
        else
            cmd_first = program_path
        end
        cmd_first = cmd_first.gsub(LKP_SRC, "$LKP_SRC")
        cmd_first  = cmd_first.gsub(lkp_src, "$LKP_SRC")

        cmd = Array(String).new
        if File.executable?(wrapper)
            cmd = [cmd_first] + [program] + args
        else
            cmd = [cmd_first] + args
        end

        return cmd
    end

    def explain_command(program_path, program, program_env, args)
        program_dir = File.dirname(program_path.to_s)

        command = Array(String).new
        case program_dir
        when %r{/monitors}
            command << "run_monitor"
        when %r{/setup$}
            command << "run_setup"

            # - 'fs2' will expand to empty in some job matrix;
            # - 'cpufreq_governor' will be defined in one include
            #    and redefined in another to be empty
            # They all mean to cancel running the setup script.
            return if program_env.empty? && args.empty? &&
                    program =~ /^(fs2|cpufreq_governor)$/
        when %r{/daemon$}
            command << "start_daemon"
        when %r{/tests$}
            command << "run_test"
            @stats_lines << "\t$LKP_SRC/stats/wrapper time #{program}.time"
        else
            command << "env" unless program_env.empty?
        end

        program_env.each do |k, v|
            command << "#{shell_encode_keyword(k)}=#{shell_escape_expand(v)}"
        end

        return command
    end

    def shell_run_program(tabs, program, env)
        program_env, args = get_program_env(program, env)
        program_path = @programs[program]? || @monitors[program]? || program

        args = Array(String).new if program_path.to_s.index("/stats/")

        cmd = combine_cmd(program_path, program, args)

        command = explain_command(program_path, program, program_env, args).not_nil!

        command.concat cmd

        exec_line unless command.first == "run_monitor" && @script_lines[-1] =~ /run_monitor/
        out_line tabs.to_s + command.join(" ")
    end

    def parse_one_programs(ancestors, key, val, pass)
        tabs = indent(ancestors)
        if @setups.keys.includes?(key)
            return false unless pass == :PASS_RUN_SETUP
        else
            return false unless pass == :PASS_RUN_COMMANDS
        end

        shell_run_program(tabs, key.sub(/^call\s+/, "").sub(/^source\s+/, "."), val)
        return :action_call_command
    end

    def parse_one_monitors(ancestors, key, val, pass)
        tabs = indent(ancestors)
        return false unless pass == :PASS_RUN_MONITORS

        shell_run_program(tabs, key, val)
        return :action_run_monitor
    end

    def parse_one_hash_val(ancestors, key, val, pass)
        if key =~ /^(if|for|while|until)\s/
            return false unless pass == :PASS_RUN_COMMANDS

            shell_block = $1
            exec_line
            exec_line tabs + key
            exec_line tabs + SHELL_BLOCK_KEYWORDS[shell_block][0]
            parse_hash(ancestors + [key], val)
            exec_line tabs + SHELL_BLOCK_KEYWORDS[shell_block][1]
            return :action_control_block
        else
            return false unless pass == :PASS_RUN_COMMANDS

            exec_line
            func_name = key.tr("^a-zA-Z0-9_", "_")
            exec_line tabs + "#{func_name}()"
            exec_line tabs + '{'
            parse_hash(ancestors + [key], val)
            exec_line tabs + "}\n"
            exec_line tabs + "#{func_name} &"
            return :action_background_function
        end
    end

    def parse_one_string_val(ancestors, key, val, pass)
        tabs = indent(ancestors)

        if key =~ %r{^script\s+(monitors|setup|tests|daemon|stats)/([-a-zA-Z0-9_/]+)$}
            return false unless pass == :PASS_NEW_SCRIPT

            script_file = $1 + '/' + $2
            script_name = File.basename $2
            if @cur_func == :run_job && script_file =~ %r{^(setup|tests|daemon)/} ||
                @cur_func == :extract_stats && script_file.index("stats/") == 0
                @programs[script_name] = LKP_SRC + '/' + script_file
            elsif @cur_func == :run_job && script_file =~ %r{^monitors/}
                @monitors[script_name] = LKP_SRC + '/' + script_file
            end

            exec_line
            exec_line tabs + "cat > $LKP_SRC/#{script_file} <<'EOF'"
            exec_line val
            exec_line "EOF"
            exec_line tabs + "chmod +x $LKP_SRC/#{script_file}"
            exec_line
            return :action_new_script
        elsif key =~ /^(function)\s+([a-zA-Z_]+[a-zA-Z_0-9]*)$/
            return false unless pass == :PASS_NEW_SCRIPT

            shell_block = $1
            func_name = $2
            exec_line
            exec_line tabs + "#{func_name}()"
            exec_line tabs + SHELL_BLOCK_KEYWORDS[shell_block][0]
            val.each_line do |l|
                exec_line "\t" + tabs + l
            end

            exec_line tabs + SHELL_BLOCK_KEYWORDS[shell_block][1]
            return :action_new_function
        end

        nil
    end

    def parse_one(ancestors, key, val, pass)
        key = key.to_s
        tabs = indent(ancestors)

        # should we judge with key at first?
        return parse_one_programs(ancestors, key, val, pass) if @programs.keys.includes?(key) || (key =~ /^(call|command|source)\s/ && @cur_func == :run_job)
        return parse_one_monitors(ancestors, key, val, pass) if @monitors.keys.includes?(key)
        return parse_one_hash_val(ancestors, key, val, pass) if val.is_a?(Hash)

        if val.is_a?(String)
            test = parse_one_string_val(ancestors, key, val, pass)
            return test if test != nil
        end

        if valid_shell_variable?(key)
            return false unless pass == :PASS_EXPORT_ENV

            if val.as_a?
                puts "<#{__FILE__}>: debug info #{val}"
                shell_export_env(tabs, key, val.as_a)
            else
                shell_export_env(tabs, key, val.to_s)
            end
            return :action_export_env
        end

        nil
    end

    def parse_hash(ancestors, hash)
        nr_bg = 0
        hash.each { |key, val| parse_one(ancestors, key, val, :PASS_EXPORT_ENV) }
        hash.each { |key, val| parse_one(ancestors, key, val, :PASS_NEW_SCRIPT) }
        hash.each { |key, val| parse_one(ancestors, key, val, :PASS_RUN_SETUP) }

        # run monitors after setup:
        # monitors/iostat etc. depends on ENV variables by setup scripts
        hash.each { |key, val| parse_one(ancestors, key, val, :PASS_RUN_MONITORS) }
        hash.each { |key, val| nr_bg += 1 if parse_one(ancestors, key, val, :PASS_RUN_COMMANDS) == :action_background_function }
    end

    def out_line(line = "")
        if line == ""
            return if @script_lines[-1] == ""
            return if @script_lines[-1] =~ /^[\s{]*$/
            return if @script_lines[-1] =~ /^\s*(then|do)$/
        end

        if line.nil?
            line = ""
        end

        @script_lines << line
    end

    def shell_header
        out_line "#!/bin/sh"
        out_line
    end

    def shell_export_env(tabs, key, val)
        exec_line tabs + "export #{key}=#{shell_escape_expand(val)}"
    end

    def to_shell
        ancestors = Array(String).new
        shell_header

        @cur_func = :run_job

        out_line "export_top_env()"
        out_line "{"

        @monitors = available_programs(:monitors)
        @setups   = available_programs(:setup)
        @programs = available_programs(:workload_elements)

        # a shallow copy so that delete_if won't impact @job
        job = @jobx.clone
        job = @job.clone if @jobx.empty?
        job.delete_if { |key, val| parse_one(ancestors, key, val, :PASS_EXPORT_ENV) }

        out_line
        out_line "\t[ -n \"$LKP_SRC\" ] ||"
        out_line "\texport LKP_SRC=/lkp/${user:-lkp}/src"
        out_line "}\n"

        out_line "run_job()"
        out_line "{"
        out_line
        out_line "\techo $$ > $TMP/run-job.pid"
        out_line
        out_line "\t. $LKP_SRC/lib/http.sh"
        out_line "\t. $LKP_SRC/lib/job.sh"
        out_line "\t. $LKP_SRC/lib/env.sh"
        out_line
        out_line "\texport_top_env"
        parse_hash ancestors, job
        out_line "}\n"

        @cur_func = :extract_stats
        out_line "extract_stats()"
        out_line "{"
        ajob = @jobx.clone
        ajob = @job.clone if @jobx.empty? == 0
        out_line "\texport stats_part_begin=#{ajob["stats_part_begin"]?}"
        out_line "\texport stats_part_end=#{ajob["stats_part_end"]?}"
        out_line
        @monitors = Hash(String, String).new
        @programs = available_programs(:stats)
        parse_hash ancestors, job
        out_line
        out_line @stats_lines.join("\n")
        yaml_hash = YAML.parse(File.read(LKP_SRC + "/etc/default_stats.yaml"))
        parse_hash ancestors, yaml_hash.as_h
        out_line "}\n"

        out_line "\"$@\""
        out_line "\n"

        @script_lines.join("\n")
    end
end
