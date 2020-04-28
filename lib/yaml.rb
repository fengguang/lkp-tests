#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require "#{LKP_SRC}/lib/common"
require "#{LKP_SRC}/lib/log"
require "#{LKP_SRC}/lib/erb"
require "#{LKP_SRC}/lib/assert"
require 'fileutils'
require 'yaml'
require 'json'
require 'English'

def compress_file(file)
  system "gzip #{file} < /dev/null"
end

def expand_yaml_template(yaml, file, context_hash = {})
  yaml = yaml_merge_included_files(yaml, File.dirname(file))
  yaml = literal_double_braces(yaml)
  expand_erb(yaml, context_hash)
end

# template_context should be nil or Hash
def load_yaml(file, template_context = nil)
  yaml = File.read file
  yaml = expand_yaml_template(yaml, file, template_context) if template_context

  begin
    result = YAML.load yaml
  rescue Psych::SyntaxError
    warn "failed to parse file #{file}"
    raise
  end

  assert result, "Possible empty file #{file}" unless template_context

  result
end

def load_yaml_with_flock(file, timeout = nil)
  lock_file = file + '.lock'

  if timeout
    with_flock_timeout(lock_file, timeout) do
      load_yaml file
    end
  else
    with_flock(lock_file) do
      load_yaml file
    end
  end
end

def load_yaml_merge(files)
  all = {}
  files.each do |file|
    next unless File.size? file

    begin
      yaml = load_yaml(file)
      all.update(yaml)
    rescue StandardError => e
      warn "#{e.class.name}: #{e.message.split("\n").first}: #{file}"
    end
  end
  all
end

def load_yaml_tail(file)
  begin
    return YAML.load %x[tail -n 100 #{file}]
  rescue Psych::SyntaxError => e
    warn "#{file}: " + e.message
  end
  nil
end

def search_file_in_paths(file, relative_to = nil, search_paths = nil)
  if file[0] == '/'
    return nil unless File.exist? file

    return file
  end

  relative_to ||= Dir.pwd

  if file =~ /^\.\.?\//
    file = File.join(relative_to, file)
    return nil unless File.exist? file

    return file
  end

  search_paths ||= [File.dirname(File.dirname(__FILE__))]
  search_paths.unshift(relative_to)

  search_paths.each do |search_path|
    path = File.join(search_path, file)
    return path if File.exist? path
  end
  nil
end

def yaml_merge_included_files(yaml, relative_to, search_paths = nil)
  yaml.gsub(/(.*)<< *: +([^*\[].*)/) do |_match|
    prefix = $1
    file = $2.chomp
    path = search_file_in_paths file, relative_to, search_paths
    raise "Included yaml file not found: '#{file}'" unless path

    to_merge = File.read path
    indent = prefix.tr '^ ', ' '
    indented = [prefix]
    to_merge.split("\n").each do |line|
      indented << if line =~ /^%([!%]*)$/
                    '%' + indent + line[1..-1]
                  else
                    indent + line
                  end
    end
    indented.join("\n")
  end
end

#
# this is specifically used for wtmp file load to handle error caused by machine crash
# though it also be extended to handle wtmp file concept
#
class WTMP
  class << self
    def load(content)
      # FIXME: rli9 YAML.load returns false under certain error like empty content
      YAML.load content
    rescue Psych::SyntaxError
      # FIXME: rli9 only do below gsub when error is control characters error
      # error can be below which is caused by server crash, and try to remove non-printable characters to resolve
      #   Psych::SyntaxError: (<unknown>): control characters are not allowed at line 1 column 1

      # remvoe all cntrl but keep \n
      YAML.load(content.gsub(/[[[:cntrl:]]&&[^\n]]/, ''))
    end

    def load_tail(file, lines = 100)
      return nil unless File.exist? file

      tail = %x[tail -n #{lines} #{file}]
      load(tail)
    rescue StandardError => e
      warn "#{file}: " + e.message
    end
  end
end

def dot_file(path)
  File.dirname(path) + '/.' + File.basename(path)
end

def save_yaml(object, file, compress = false)
  temp_file = dot_file(file) + "-#{tmpname}"
  File.open(temp_file, 'w') do |f|
    f.write(YAML.dump(object))
  end
  FileUtils.mv temp_file, file, force: true

  return unless compress

  FileUtils.rm "#{file}.gz", force: true
  compress_file(file)
end

def save_yaml_with_flock(object, file, timeout = nil, compress = false)
  lock_file = file + '.lock'

  if timeout
    with_flock_timeout(lock_file, timeout) do
      save_yaml object, file, compress
    end
  else
    with_flock(lock_file) do
      save_yaml object, file, compress
    end
  end
end

$json_cache = {}
$json_mtime = {}

def load_json(file, cache = false)
  file += '.gz' if file =~ /.json$/ && File.exist?(file + '.gz')
  if file =~ /.json(\.gz)?$/ && File.exist?(file)
    begin
      mtime = File.mtime(file)
      unless $json_cache[file] && $json_mtime[file] == mtime
        obj = if file =~ /\.json$/
                JSON.load File.read(file)
              else
                JSON.load `zcat #{file}`
              end
        return obj unless cache

        $json_cache[file] = obj
        $json_mtime[file] = mtime
      end
      return $json_cache[file].freeze
    rescue SignalException
      raise
    rescue StandardError
      tempfile = file + '-bad'
      warn "Failed to load JSON file: #{file}"
      warn "Kept corrupted JSON file for debugging: #{tempfile}"
      FileUtils.mv file, tempfile, force: true
      raise
    end
    nil
  elsif File.exist? file.sub(/\.json(\.gz)?$/, '.yaml')
    load_yaml file.sub(/\.json(\.gz)?$/, '.yaml')
  else
    warn "JSON/YAML file not exist: '#{file}'"
    warn caller
    nil
  end
end

def save_json(object, file, compress = false)
  temp_file = dot_file(file) + "-#{tmpname}"
  File.open(temp_file, 'w') do |file|
    file.write(JSON.pretty_generate(object, allow_nan: true))
  end
  FileUtils.mv temp_file, file, force: true

  return unless compress

  FileUtils.rm "#{file}.gz", force: true
  compress_file(file)
end

def try_load_json(path)
  if File.file? path
    load_json(path)
  elsif path =~ /.json$/
    if File.file? path + '.gz'
      load_json(path + '.gz')
    elsif File.file? path.sub(/\.json$/, '.yaml')
      load_json(path)
    end
  end
end

class JSONFileNotExistError < StandardError
  def initialize(path)
    super "Failed to load JSON for #{path}"
    @path = path
  end

  attr_reader :path
end

def load_merge_jsons(path)
  return nil unless path.index(',')

  files = path.split(',')
  files.each do |file|
    return nil unless File.exist? file
  end

  matrix_from_stats_files(files)
end

def search_load_json(path)
  try_load_json(path) ||
    try_load_json(path + '/matrix.json') ||
    try_load_json(path + '/stats.json') ||
    load_merge_jsons(path) ||
    raise(JSONFileNotExistError, path)
end

def search_json(path)
  search_load_json path
rescue JSONFileNotExistError
  false
end

def load_regular_expressions(file, options = {})
  pattern = File.read(file).split("\n")
  spec = "#{options[:prefix]}(#{pattern.join('|')})#{options[:suffix]}"
  Regexp.new spec
end
