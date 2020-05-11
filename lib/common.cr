#LKP_SRC = ENV["LKP_SRC"] || File.dirname(__DIR__)

## common utilities

#require "timeout"
require "file_utils"
require "./array_ext"

# require "pathname"
# require "stringio"
# require "English"

def deepcopy(o)
  Marshal.load(Marshal.dump(o))
end

# Take a look at class Commit for usage
module AddCachedMethod
  def add_cached_method(method_name, prefix = "cached_")
    define_method("#{prefix}#{method_name}") do |key, *args|
      @__cache_for_add_cached_method__ ||= Hash(String, String).new
      cache = @__cache_for_add_cached_method__
      mkey = [method_name, key]
      cache[mkey] ||= send(method_name, *args)
    end
  end
end

def instance_variable_sym(str)
  "@#{str}".intern
end

def with_set_globals(*var_val_list)
  var_vals = var_val_list.each_slice(2).to_a
  ovals = var_vals.map { |var, val| eval(var.to_s) }
  var_vals.each { |var, val| eval "#{var} = val" }
  yield
ensure
  if ovals
    var_vals.zip(ovals).map do |var_val, oval|
      var, _val = var_val
      eval("#{var} = oval")
    end
  end
end

def ensure_array(obj)
  if obj.is_a? Array
    obj
  else
    [obj]
  end
end

def array_add!(arr_dst, arr_src)
  0.upto(arr_dst.size - 1) do |i|
    arr_dst[i] += arr_src[i]
  end
end

# Array "-" + "uniq!" with block to calculate key
def array_subtract(arr1, arr2)
  if block_given?
    harr = Hash(String, String).new
    arr1.each do |e|
      harr[yield(e)] = e
    end
    arr2.each do |e|
      harr.delete yield(e)
    end
    harr.values
  else
    arr1 - arr2
  end
end

def string_to_num(str)
  str.index(".") ? str.to_f : str.to_i
end

def array_diff_index(arr1, arr2)
  s = [arr1.size, arr2.size].min
  (0...s).each do |i|
    return i if arr1[i] != arr2[i]
  end
  s
end

def array_common_head(arr1, arr2)
  s = array_diff_index arr1, arr2
  arr1[0...s] || Array(String).new
end

def remove_common_head(arr1, arr2)
  s = array_diff_index arr1, arr2
  [arr1[s...arr1.size] || Array(String).new, arr2[s...arr2.size] || Array(String).new]
end

# To workaround const_defined?('A::B') error on some ruby version
def get_the_const(name)
  Object.const_get(name)
rescue NameError
  nil
end

## IO

def format_number(number)
  case number
  when Float
    an = number.abs
    fmt =
      if an < 0.001
        "%.4g"
      elsif an < 1
        "%.4f"
      elsif an < 1000
        "%.2f"
      elsif an < 100_000_000
        "%.1f"
      else
        "%.4g"
      end
    s = format(fmt, number)
    # Remove trailing 0
    if fmt[-1] == "f"
      s.gsub(/\.?0+$/, "")
    else
      s
    end
  else
    number.to_s
  end
end

## Pathname

def ensure_dir(dir)
  dir[-1] == "/" ? dir : dir + "/"
end

def split_path(path)
  path.split("/").select { |c| c && !c.empty? }
end

def canonicalize_path(path, dir = nil)
  abs_path = File.absolute_path(path, dir)
  Pathname.new(abs_path).cleanpath.to_s
end

def path_escape(path)
  path.tr("/", "_")
end

module DirObject
  def to_s
    @path
  end

  def path(*sub)
    File.join @path, *sub
  end

  def open(sub, *args, &b)
    sub = ensure_array(sub)
    File.open path(*sub), *args, &b
  end

  def glob(pattern, flags = nil, &b)
    fpattern = path pattern
    if flags
      Dir.glob fpattern, flags, &b
    else
      Dir.glob fpattern, &b
    end
  end

  def chdir(&b)
    Dir.chdir @path, &b
  end

  def run_in(cmd)
    chdir do
      system cmd
    end
  end

  def bash
    run_in("/bin/bash -i")
  end
end

## IO redirection

# --- not test yet
def redirect_to(io)
  # not implement yet
end

def pager(&b)
  pager_prog = ENV["PAGER"] || "/usr/bin/less"
  IO.popen(pager_prog, "w") do |io|
    redirect_to io, &b
  end
end

def redirect_to_file(*args, &b)
  args = ["stdout.txt", "w"] if args.empty?
  File.open(*args) do |f|
    redirect_to f, &b
  end
end

def redirect_to_string(&b)
  StringIO.open("", "w") do |so|
    redirect_to so, &b
    so.string
  end
end
# ---

def monitor_file(file, history = 10)
  system("tail", ["-f", "-n", history.to_s, file])
end

def zopen(fn, mode = "r", &blk)
  fn = fn.sub(/(\.xz|\.gz)$/, "")
  if File.exists?(fn)
    f = File.open(fn, mode)
    yield f
    f.close
  elsif File.exists?(fn + ".xz")
    fullpath = File.expand_path(fn + ".gz")
    args=[fn + ".gz"]
    process = Process.new("xzcat",  args)
    yield process
  elsif File.exists?(fn + ".gz")
    fullpath = File.expand_path(fn + ".gz")
    args=[fn + ".gz"]
    process = Process.new("zcat",  args)
    yield process
  else
    raise "File doesn't exist: #{fn}"
  end
end

def copy_and_decompress(src_fullpath, dst)
  src_fullpath = src_fullpath.sub(/(\.xz|\.gz|\.bz2)$/, "")
  
  if Dir.exists? dst
    fn = File.basename(src_fullpath, ".*")
    dst = File.join(dst, fn)
  end

  if File.exists?(src_fullpath)
    %x(cp #{src_fullpath} #{dst})
  elsif File.exists?(src_fullpath + ".gz")
    src_fullpath += ".gz"
    %x(gzip -cd #{src_fullpath} > #{dst})
  elsif File.exists?(src_fullpath + ".bz2")
    src_fullpath += ".bz2"
    %x(bzip2 -cd #{src_fullpath} > #{dst})
  elsif File.exists?(src_fullpath + ".xz")
    src_fullpath += ".xz"
    %x(xz -cd #{src_fullpath} > #{dst})
  else
    STDERR << "File doesn't exist: #{src_fullpath}"
    return false
  end

  $?.success?
end

## Date and time

ONE_DAY = 60 * 60 * 24
DATE_GLOB = "????-??-??"

def str_date(t)
  t.to_s("%F")
end

def date_of_time(t)
  if t
    Time.local t.year, t.month, t.day
  else
    Time.local
  end
end

## File system

def make_relative_symlink(src, dst)
  dst = File.join(dst, File.basename(src)) if File.directory? dst
  return if File.exists? dst

  src_comps = split_path(src)
  dst_comps = split_path(dst)
  src_comps, dst_comps = remove_common_head(src_comps, dst_comps)
  rsrc = File.join([".."] * (dst_comps.size - 1) + src_comps)
  File.symlink(rsrc, dst)
end

def mkdir_p(dir, mode = 0o2775)
  FileUtils.mkdir_p dir, mode: mode
end

def with_flock(lock_file)
  File.open(lock_file, "w+", 0o664) do |f|
    f.flock_exclusive
    yield
  end
end

def with_flock_timeout(lock_file, timeout)
  File.open(lock_file, "w+", 0o664) do |f|
    Timeout.timeout(timeout * 1.0) do
      f.flock_exclusive
    end
    yield
  end
end

def delete_file_if_exist(file)
  File.delete(file) if File.exists?(file)
end

def dowrite(f)
  f.puts "1234"
end


#tested: monitor_file("/tmp/1.txt")

#tested: zopen("pkg/ocfs2test-addon/timing-0.0.1.tar.gz") { |p| p p } 
#               zopen("pkg/ocfs2test-addon/timing-0.0.1.tar.gzz") {puts "block"}
#               zopen("/tmp/1.txt", "w+") do |f|
#                   f.puts("abcd")
#                   f.puts("abcd")
#               end

# tested: copy_and_decompress("pkg/ocfs2test-addon/timing-0.0.1.tar.gz", "/tmp")
#                copy_and_decompress("pkg/ocfs2test-addon/timing-0.0.1.tar.gzz", "/tmp")

# tested: str_date(Time.local)
# tested: date_of_time(nil)

# tested: make_relative_symlink("/tmp/1", "/tmp/2")
#  - cover: split_path remove_common_head

# tested: mkdir_p("/tmp/testdir")
# tested: with_flock("/tmp/testfile") { puts "a" }

#dependencies:
#  timeout:
#    github: ctiapps/timeout
# tested: with_flock_timeout("/tmp/testfile", 12) { puts "a" }

# tested: delete_file_if_exist("/tmp/testfile")

