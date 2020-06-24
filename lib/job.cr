require "yaml"

LKP_SRC = ENV["LKP_SRC"]? || "/c/lkp-tests"

class Job
    class ParamError < ArgumentError
    end
end

class Job
    def initialize
        @jobs =Array(YAML::Any).new
        @job = Hash(YAML::Any, YAML::Any).new
        @jobx = Hash(YAML::Any, YAML::Any).new
        @jobfile = String.new

        @available_programs = Hash(Symbol, Hash(String, String)).new
        @programs_cache = Hash(String, Hash(String, String)).new
        @programs = Hash(String, String).new
    end

    def load(jobfile, expand_template = false)
        yaml = File.read jobfile
        ArgumentError.new("empty jobfile #{jobfile}") if yaml.empty?
        @jobs = YAML.parse_all(yaml)

        # if can not find @jobs.first["job_origin"]
        # no need <try symlink? or Add a symbol :#! filename>
        jobs_hash = @jobs.shift.as_h
        @job.merge!(jobs_hash)
        if @job["job_origin"]? == nil
          @job.merge!( YAML.parse("job_origin: #{jobfile}").as_h)
        end
        @jobfile = jobfile
    end

    def lkp_src
        if @job["user"]? && Dir.exists?("/lkp/" + @job["user"].to_s + "/src")
            "/lkp/" + @job["user"].to_s + "/src"
        else
            LKP_SRC
        end
    end

    def expand_params(run_scripts = true)
    end

    def atomic_job?
        true
    end

    def __create_programs_hash(glob, lkp_src)
        programs = Hash(String, String).new

        Dir.glob("#{lkp_src}/#{glob}").each do |path|
            next if File.directory?(path)
            next if path =~ /\.yaml$/
            next if path =~ /\.[0-9]+$/

            unless File.executable?(path)
                puts "skip non-executable #{path}" unless path =~ /\.cr$/
                next
            end

            file = File.basename(path)
            next if file == "wrapper"

            if programs.includes? file
                puts "Conflict names #{programs[file]} and #{path}"
                next
            end

            programs[file] = path
        end

        programs
    end

    def create_programs_hash(glob, lkp_src = LKP_SRC)
        cache_key = [glob, lkp_src].join ':'
        if @programs_cache[cache_key]? == nil
            @programs_cache[cache_key] = __create_programs_hash(glob, lkp_src)
        end
        @programs = @programs_cache[cache_key]
    end

    def available_programs(type)
        case type
        when Array
          p = Hash(String, String).new
          type.each do |t|
            p.merge! available_programs(t)
          end
          return p
        when :workload_and_monitors
          # This is all scripts that run in testbox.
          # The other stats/* and filters/* run in server.
          if @available_programs[:workload_and_monitors]? == nil
            @available_programs[:workload_and_monitors] = available_programs(%i(workload_elements monitors))
          end
          return @available_programs[:workload_and_monitors]
        when :workload_elements
          # the options of these programs could impact test result
          if @available_programs[:workload_elements]? == nil
            @available_programs[:workload_elements] = available_programs(%i(setup tests daemon))
          end
          return @available_programs[:workload_elements]
        else
            if @available_programs[type]? == nil
              @available_programs[type] = create_programs_hash("#{type}/**/*", lkp_src)
            end
            return @available_programs[type]
        end
    end
end
