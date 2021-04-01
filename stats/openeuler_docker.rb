#!/usr/bin/env ruby

def pre_handel(result, file_path)
  status = false
  repo_set = Set[]
  sys_set = Set[]

  File.readlines(file_path).each do |line|
    case line.chomp!

    # Error: Unable to find a match: docker-registry mock xx
    when /Error: Unable to find a match: (.+)/
      $1.split.each do |repo|
        repo_set << repo
      end

    # RUN yum -y swap -- remove fakesystemd -- install systemd systemd-libs
    # yum swap: error: unrecognized arguments: install systemd systemd-libs
    when /yum swap: error: .*: install (.+)/
      $1.split.each do |sys|
        sys_set << sys
      end

    # curl: (22) The requested URL returned error: 404 Not Found
    # error: skipping https://dl.fedoraproject.org/pub/epel/bash-latest-7.noarch.rpm - transfer failed
    when /.*error: .* (https.*)/
      result['requested-URL-returned.error'] = [1]
      result['requested-URL-returned.error.message'] = [line.to_s]
      status = true

    # Error: Unknown repo: 'powertools'
    when /Error: Unknown repo: (.+)/
      repo = $1.delete!("'")
      result["unknown-repo.#{repo}"] = [1]
      result["unknown-repo.#{repo}.message"] = [line.to_s]
      status = true

    # Error: Module or Group 'convert' does not exist.
    when /Error: Module or Group ('[^\s]+')/
      repo = $1.delete!("'")
      result["error.not-exist-module-or-group.#{repo}"] = [1]
      result["error.not-exist-module-or-group.#{repo}.message"] = [line.to_s]
      status = true

    # /bin/sh: passwd: command not found
    when /\/bin\/sh: (.+): command not found/
      result["sh.command-not-found.#{$1}"] = [1]
      result["sh.command-not-found.#{$1}.message"] = [line.to_s]
      status = true
    end

    repo_set.each do |repo|
      result["yum.error.Unable-to-find-a-match.#{repo}"] = [1]
      result["yum.error.Unable-to-find-a-match.#{repo}.message"] = ["Error: Unable to find a match #{repo}"]
      status = true
    end

    sys_set.each do |sys|
      result["yum.swap.error.unrecognized-arguments-install.#{sys}"] = [1]
      result["yum.swap.error.unrecognized-arguments.#{sys}.message"] =
        ["yum swap: error: unrecognized arguments install #{sys}"]
      status = true
    end
  end
  status
end

def handle_unknown_error(_result, file_path)
  line_num = %x(cat #{file_path} | grep -n 'Step '  | tail -1 | awk -F: '{print $1}')

  index = 1
  message = ''
  File.readlines(file_path).each do |line|
    if index == Integer(line_num)
      message += line
    else
      index += 1
    end
  end

  message = $1 if message =~ %r(\u001b\[91m(.+))
  message
end

def openeuler_docker(log_lines)
  result = Hash.new { |hash, key| hash[key] = [] }

  log_lines.each do |line|
    next unless line =~ %r(([^\s]+).(build|run)\.fail)

    key, value = line.split(':')
    key.chomp!
    result[key] << value.to_i

    file_path = "#{RESULT_ROOT}/#{$1}" # $1 named by docker-image name
    next unless File.exist?(file_path)
    next if pre_handel(result, file_path)

    result["#{key}.message"] << handle_unknown_error(result, file_path)
  end

  result
end
