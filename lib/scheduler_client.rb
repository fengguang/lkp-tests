# frozen_string_literal: true

require 'rest-client'

# scheduler client class
class SchedulerClient
  def initialize(host = '127.0.0.1', port = 3000)
    @host = host
    @port = port
  end

  def submit_job(job_json)
    url_prefix = ''
    if @host.match('.*[a-zA-Z]+.*')
      # Internet users should use domain name and https
      url_prefix = 'https://'
    else
      # used in intranet for now
      url_prefix = 'http://'
    end

    resource = RestClient::Resource.new("#{url_prefix}#{@host}:#{@port}/submit_job")
    resource.post(job_json)
  end
end
