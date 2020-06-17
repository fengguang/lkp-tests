require "option_parser"

require "../lib/job2sh"
require "../lib/log"

destination = ""
output = STDOUT

OptionParser.parse do |parser|
    parser.banner = "Usage: #{PROGRAM_NAME} [options] job.yaml"
    parser.on("-o FILE", "--output FILE", "save shell script to FILE (default: stdout)") { |name| destination = name }
    parser.on("-h", "--help", "Show this message") do
        puts parser
        exit
    end
    parser.invalid_option do |flag|
        STDERR.puts "ERROR: #{flag} is not a valid option."
        STDERR.puts parser
        exit(1)
    end
end

if destination != ""
    output = File.open(destination, "w+")
end

begin
    job = Job2sh.new
    job.load(ARGV[0])
    job.expand_params

    unless job.atomic_job?
      log_error "Looks #{ARGV[0]} isn't a atomic jobfile, only atomic jobfile is supported"
      log_error "Please run 'lkp split-job #{ARGV[0]}' first"
      exit(1)
    end
  rescue e : Job::ParamError
    log_error "Abandon job: #{e.message}"
    exit(1)
  rescue e
    log_error "#{e.message}"
    exit(1)
end

output.puts job.to_shell
if destination != ""
    output.close
end
