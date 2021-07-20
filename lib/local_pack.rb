#!/usr/bin/env ruby

require 'yaml'
require 'fileutils'
require 'digest'
require 'base64'

# used to do package for user side
# pack_source
#   get lkp_tag
#     - last repo tag for the repo
#   extract_modified_files
#     - extract modifiled files since the last
#     copy_file
#       - copy modified file to /lkp/lkp/src
#   extract_new_files
#     - extract untracked files
#     copy_file
#       - copy modified file to /lkp/lkp/src
#   check_difference
#     - check if there is any change since last pack
#     - if no change, skip and use the on packaged last time
#     - if changed, do new package
#   backup files
#     - copy extracted file to specified dir
#     - used to do the 'check_difference' for the next time
class PackChange
  def initialize(repo_dir)
    @repo_dir = repo_dir
    @repo_name = File.basename(@repo_dir)
    @base_home = "#{ENV['HOME']}/lkp-pkg-files"
    @dest_home = "#{@base_home}/lkp"
    @dest_test_home = if @repo_name == 'lkp-tests'
                        "#{@base_home}/LKP_SRC"
                      else
                        "#{@base_home}/LKP_SRC2"
                      end

    @cgz_dir = "#{ENV['HOME']}/srv/initrd/lkp"
    @pass_file_type = %w[.md .bk .swp .zip .bak .yml]
  end

  def copy_file(file)
    if @repo_name == 'lkp-tests'
      return if file.start_with?('sbin/')

      return if file.start_with?('jobs/')
    end

    # ignored file extension: '.md', '.bk', '.swp', '.zip', '.bak', '.yml'
    file_extension = File.extname(file)
    return if @pass_file_type.include? file_extension

    file_relate_path = File.dirname(file)
    dest_dir = "#{@dest_home}/lkp/src/#{file_relate_path}"
    FileUtils.mkdir_p(dest_dir) unless File.exist?(dest_dir)

    if file.end_with?('/')
      FileUtils.cp_r("#{@repo_dir}/#{file}", dest_dir.to_s)
    else
      FileUtils.copy("#{@repo_dir}/#{file}", dest_dir.to_s)
    end
  end

  def extract_modified_files(lkp_tag)
    FileUtils.chdir @repo_dir
    modified_file_list = %x(git diff --name-only #{lkp_tag}).split("\n")

    return if modified_file_list.empty?

    modified_file_list.each do |file|
      copy_file(file)
    end
  end

  def extract_new_files
    FileUtils.chdir @repo_dir
    new_file_list = %x(git status --short | grep -v "^ *M"| awk '{print $2}').split("\n")

    return if new_file_list.empty?

    new_file_list.each do |file|
      copy_file(file)
    end
  end

  def check_difference
    return false if Dir.empty? @dest_test_home

    return true if %x(diff -urNa #{@dest_test_home} #{@dest_home}).empty?

    false
  end

  def pack_source
    FileUtils.remove_dir "#{@dest_home}/lkp" if Dir.exist? "#{@dest_home}/lkp"

    tag = %x(git describe --abbrev=0 --tags).chomp

    if tag.empty?
      err_msg = 'Please update your repo and then try again.'
      raise err_msg
    end

    extract_modified_files(tag)
    extract_new_files

    dest_cgz = "#{@cgz_dir}/#{@repo_name}.cgz"
    FileUtils.mkdir_p(@dest_test_home) unless Dir.exist? @dest_test_home

    unless check_difference
      FileUtils.mkdir_p(@cgz_dir) unless Dir.exist? @cgz_dir

      %x(touch #{dest_cgz}) unless File.exist? dest_cgz
      %x(cd "#{@base_home}" && find lkp | cpio -o -H newc | gzip -N -9 > "#{dest_cgz}")
    end

    md5 = Digest::MD5.hexdigest File.read(dest_cgz)
    content = Base64.encode64(File.read(dest_cgz)).chomp

    FileUtils.remove_dir "#{@dest_test_home}/lkp" if Dir.exist? "#{@dest_test_home}/lkp"
    FileUtils.cp_r "#{@dest_home}/lkp", @dest_test_home

    [tag, md5, content]
  end
end
