# Linux Kernel Performance tests on Ubuntu 14.04
  You can find out how to execute sections of "Getting started" and "Install packages for a job" in "README.md",then follow the commands in the document.

## Run your own benchmarks
  $ lkp split-job lkp-tests/jobs/mytest.yaml
  
  output is:
  /usr/lib/ruby/1.9.1/rubygems/custom\_require.rb:36:in `require':
  /home/user/lkp-tests/lib/job.rb:406: unknown type of %string (SyntaxError)
  available\_programs %i(workload\_elements monitors)
  /home/user/lkp-tests/lib/job.rb:406: syntax error, unexpected $end, expecting keyword_end
  available\_programs %i(workload\_elements monitors)
  from /usr/lib/ruby/1.9.1/rubygems/custom\_require.rb:36:in'require'
  from /home/user/lkp-tests/sbin/split-job:5:in'<.main>'

  As can be seen from the output of the terminal,some syntax error occurred in some ruby files,because the system's ruby version is not compatible with the syntax in these ruby files.We need to upgrade the system's ruby version to 2.0 or above to accommodate the syntax in these files.

## View your ruby version  
  $ ruby -v
  
  output is:
  ruby 1.9.3p484 (2013-11-22 revision 43786) [x86_64-linux]
  
  The current ruby version of the system is ruby 1.9,which is lower than the required minimum ruby version of ruby 2.0.We need to upgrade the ruby version to ruby 2.0 or above.

## Download and Update ruby version
  $ sudo -E apt-get install ruby
  $ sudo -E add-apt-repository ppa:brightbox/ruby-ng
  $ sudo apt-get update
  $ sudo -E apt-get install ruby2.3
  $ sudo -E apt-get install ruby2.3-dev
  $ sudo -E gem update --system -V
  $ sudo -E gem update -V

## View your ruby version
  $ ruby -v
  
  output is:
  ruby 2.3.7p456 (2018-03-28 revision 63024) [x86_64-linux-gnu]
  
  The ruby version of the system has been upgraded to ruby 2.3,which matches the minimum ruby version of ruby 2.0.

## Change package name
  Terminal may output"Unable to locate package libunwind-dev" after you run mytest.yaml.You can solve it by change "libunwind-dev" to "libunwind8-dev"in the file of "~/lkp-tests/distro/depends/perf-dev".



