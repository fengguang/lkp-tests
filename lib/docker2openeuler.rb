#!/usr/bin/ruby
# frozen_string_literal: true

# What's purpose:
#	convert Dockerfile file from centos[7|8] or fedora to openeuler-20.03-lts-sp1
# How to use:
#	cmd: ruby docker2openeuler.rb ${dockerfile} ${os_version}
#	params:
#		- dockerfile: Dockerfile file
#		- os_version: choice as follow: centos7 | centos8 | fedora

def replace_base_image(line, os_version)
  centos_tag = "centos(:7|7|:centos7|:8|8|:centos8|)(:latest)?"
  centos_from = "^FROM #{centos_tag}( .*)?"
  if line =~ Regexp.new(centos_from)
    line.gsub!(Regexp.new(centos_tag), os_version)
    line += "\nRUN yum --nogpgcheck -y -q install npm cronie python2-pip yum-utils shadow tar make passwd python3-pip.noarch glibc-locale-source glibc-langpack-en"
    line += "\nRUN yum remove -y dnf-plugins-core | yum install -y dnf-plugins-core\n"
  end

  line
end

def replace_image_context(repo_name,line)
  if repo_name == "patriceckhart/docker-lap" && line =~ %r{php-pspell}
    new_cmd = "RUN sh -c \"echo -e '[centos]\\nname=centos php\\nbaseurl=http://mirror.centos.org/altarch/7/os/aarch64\\nenabled=1\\ngpgcheck=0' >> /etc/yum.repos.d/php.repo\"\n"
    line = new_cmd + line
  end

  # grep -qw "groupadd*" "$file" && {
  # fix missing useradd, groupadd, chpasswd, etc. commands
  line.gsub!(/rpm --rebuilddb/,
             "bash -c 'rpm --rebuilddb; rm -rf /var/lib/rpm; mv /var/lib/rpmrebuilddb.* /var/lib/rpm;yum clean all \&\& rpm --rebuilddb'")
  line.gsub!(%r{https://github}, 'git://github') if line =~ %r{git clone https://}
  line.gsub!(/ (centos|epel)-release($|.noarch| )/, ' openEuler-release ')

  # repo: git://github.com/wxx213/test.git
  # fix Status code: 404 for http://nginx.org/packages/centos/20.03LTS_SP1/aarch64/repodata/repomd.xml
  # line.gsub!(/http://nginx.org/packages/centos/"\$releasever"\/, "http://nginx.org/packages/centos/7")

  # repo: git://github.com/anandbaghel/Dev.git
  # yum update all => yum update
  line.gsub!(/(yum update) all/, '\1')
  line.gsub!(/(yum makecache) fast/, '\1')

  # repo: git://github.com/almacro/snippets.git
  # install nginx for openEuler-20.03-LTS-SP1, not exist file "/etc/nginx/conf.d/default.conf"
  line.gsub!(%r{(/etc/nginx/conf.d/default.conf).*}, '\1 > /dev/null 2&>1 || echo')

  # repo: git://github.com/aak74/bitrix-docker.git
  # rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7
  # https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 =>
  # /etc/pki/rpm-gpg/RPM-GPG-KEY-openEuler
  line.gsub!(%r("?https?://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7"?), "/etc/pki/rpm-gpg/RPM-GPG-KEY-openEuler")

  # replace RPM-GPG-KEY-CentOS-7 | RPM-GPG-KEY-centosofficial | RPM-GPG-KEY-EPEL-7
  # => RPM-GPG-KEY-openEuler
  line.gsub!(/RPM-GPG-KEY-(CentOS-7|centosofficial|EPEL-7)/, 'RPM-GPG-KEY-openEuler')

  # git://github.com/jeroldleslie/deployments.git
  # For openEuler, not support command:
  #   yum -y swap -- remove systemd-container* -- install systemd systemd-libsibs
  # But can convert it like this:
  #   yum -y remove fakesystemd && yum -y install systemd systemd-libs
  line.gsub!(/yum (.*) swap -- remove (.*) -- install/, 'yum \1 remove \2 && yum \1 install')

  # yum --enablerepo=base clean metadata -y
  # yum -y --enablerepo=extras install epel-release
  line.gsub!(/--enablerepo=(base|powertools|extras)/, '--enablerepo=everything')

  # repo: git://github.com/mwilck/build-multipath.git
  # not support repo source 'powertools' for openeuler
  # dnf config-manager --set-enabled powertools
  # => dnf config-manager --set-enabled everything
  line.gsub!(/--set-enabled powertools/, '--set-enabled everything')

  # repo: git://github.com/moremagic/docker-firefox.git
  # after install 'openssh-server' package for openeuler, sshd-keygen script change position.
  # /usr/sbin/sshd-keygen => /usr/libexec/openssh/sshd-keygen rsa
  line.gsub!(%r(/usr/sbin/sshd-keygen), '/usr/libexec/openssh/sshd-keygen rsa')
  line.gsub!(/ sshd-keygen/, ' /usr/libexec/openssh/sshd-keygen rsa')

  # CentOS-Base.repo => openEuler.repo
  line.gsub!(/CentOS-Base.repo/, 'openEuler.repo')

  # delete  epel.repo | CentOS-Base.repo
  # sed -i -e '0,/#baseurl/ s/#baseurl/baseurl/' /etc/yum.repos.d/CentOS-Base.repo &&
  # wget ......Centos-Base.repo
  # yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  line.gsub!(/(^[A-Z]*|[;&]*)(.*(epel|docker-ce).repo[ ;&]*)/, '\1 ')

  # repo: git://github.com/b01/docker-images.git
  # errors:
  #  - https://dl.fedoraproject.org/pub/epel/bash-latest-8.noarch.rpm
  #    https://mirrors.aliyun.com/epel/epel-release-latest-7.noarch.rpm =>
  #    https://repo.openeuler.org/openEuler-20.03-LTS-SP1/everything/aarch64/Packages/bash-5.0-14.oe1.aarch64.rpm
  #  - https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm =>  \
  #    https://repo.openeuler.org/openEuler-20.03-LTS-SP1/everything/aarch64/Packages/openEuler-release-20.03LTS_SP1-38.oe1.aarch64.rpm
  #  - rpm -Uvh https://repo.openeuler.org/openEuler-20.03-LTS-SP1/everything/aarch64/Packages/openEuler-release-20.03LTS_SP1-38.oe1.aarch64.rpm
  #  - yum install -y https://repo.openeuler.org/openEuler-20.03-LTS-SP1/everything/aarch64/Packages/openEuler-release-20.03LTS_SP1-38.oe1.aarch64.rpm
  repo_source = 'https://repo.openeuler.org/openEuler-20.03-LTS-SP1/everything/aarch64/Packages'
  line.gsub!(%r("?https?://(dl.fedoraproject.org|mirrors.aliyun.com).*epel-release.*\.rpm"?),
             "#{repo_source}/openEuler-release-20.03LTS_SP1-38.oe1.aarch64.rpm || echo")
  line.gsub!(%r("?https?://dl.fedoraproject.org.*bash.*\.rpm"?), "#{repo_source}/bash-5.0-14.oe1.aarch64.rpm || echo")

  # repo: git://github.com/lorenzogirardi/k8s-helloworld.git
  # For centos7, it doesn't have nginx package, which firstly need to install 'nginx-release-centos-7-0.el7.ngx.noarch.rpm',
  # secondly install nginx. And for openEuler, we can derectly install nginx by nginx-1.16.1-7.oe1.aarch64.rpm.
  # - http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm => \
  #   https://repo.openeuler.org/openEuler-20.03-LTS-SP1/everything/aarch64/Packages/nginx-1.16.1-7.oe1.aarch64.rpm
  line.gsub!(%r("?https?://nginx.org/packages/centos.*nginx-release-centos.*\.rpm"?),
             "#{repo_source}/nginx-1.16.1-7.oe1.aarch64.rpm || echo")

  # repo: git://github.com/hnakamur/centos7-vagrant-docker-compose-example.git
  # error: COPY nginx.repo /etc/yum.repos.d/nginx.repo
  # delete COPY error
  line.gsub!(%r((^COPY nginx.repo /etc/yum.repos.d/nginx.repo).*), '# \1')

  # openeuler exist /usr/bin/python
  line.gsub!(%r{ln[^;&]*/usr/bin/python\s*(&&)*\s*}, '')

  # repo: git://github.com/jarod/TarsCloud-Tars-builder.git
  # errors: ln: failed to create symbolic link '/usr/bin/cmake': File exists
  # ln -s
  # /usr/bin/cmake3 /usr/bin/cmake     &&
  line.gsub!(%r{ln[^;&]*/usr/bin/cmake\s*(&&)*\s*}, '')

  # openeuler doesn't support unknown key type rsa1\r
  line.gsub!(/ rsa1/, ' rsa') if line =~ /ssh-keygen.*-t rsa1/

  # repo: git://github.com/cgi-eoss/ftep-build-container.git
  # errors: /etc/yum/pluginconf.d/fastestmirror.conf => /etc/yum/pluginconf.d/local.conf
  line.gsub!(/fastestmirror\.conf/, 'local.conf') if line =~ %r{/etc/yum/pluginconf\.d/fastestmirror\.conf}

  # bash -e
  line.gsub!(/ bash/, ' bash -e') if line =~ /bash .*\.sh/
  line.gsub!(%r(\s+), ' ')
  line.gsub!(/&&/, "&& \\\n  ") if line =~ /^[^#].*/
  line
end

def handle_build_sh_script(dockerfile)
  #  modify build.sh script; eg: git://github.com/GaykarSanket/bigtop.git
  dockerfile_path = File.dirname(dockerfile)
  return unless File.exist?("#{dockerfile_path}/build.sh")

  `sed -i '/docker build.*--pull=true.*/ s| --pull=true||g' "#{dockerfile_path}/build.sh"`
end

def start_process_dockerfile_context(repo_name,new_dockerfile_context, dockerfile, os_version)
  File.delete(dockerfile) if File.exist?(dockerfile)
  new_dockerfile_context.each do |line|
    line = if line =~ /^FROM.+/
             replace_base_image(line, os_version)
           else
             replace_image_context(repo_name,line)
           end

    File.open(dockerfile, 'a+') do |f|
      f.write("#{line}\n")
    end
  end
end

# read old Dockerfile to array
def pre_process_dockerfile(new_dockerfile_context, dockerfile)
  one_line = ''
  File.foreach(dockerfile) do |line|
    next if line =~ %r(^\n$)
    next if line =~ /^#.*/

    line.gsub!(/(.*)\\(\s*\n)/, '\1\2')
    if line =~ /^[\s\t]*[A-Z]+(?=\s+)/
      new_dockerfile_context << one_line unless one_line.empty?
      line.strip!
      one_line = line
    else
      next if line =~ /[\s\t]+#.*/

      one_line.chomp!
      one_line += line
    end
  end

  new_dockerfile_context << one_line unless one_line.empty?
end

def main
  dockerfile = ARGV[0]
  # os_version:  openeuler:20.03-LTS-SP1 | openeuler:20.03-LTS-SP1-ALL | openeuler:20.03-LTS-SP1-ALL-DNF
  os_version = ARGV[1]
  repo_name = ARGV[2]
  new_dockerfile_context = []

  if dockerfile.nil? || os_version.nil? || dockerfile.empty? || os_version.empty?
    puts 'params is empty'
    exit
  end

  pre_process_dockerfile(new_dockerfile_context, dockerfile)
  start_process_dockerfile_context(repo_name,new_dockerfile_context, dockerfile, os_version)
  handle_build_sh_script(dockerfile)
end

main
