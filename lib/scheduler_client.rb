# frozen_string_literal: true

require 'rest-client'

# scheduler client class
class SchedulerClient
  def initialize(host = '127.0.0.1', port = 3000)
    @host = host
    @port = port
  end

  def submit_job(job_json)
    resource = RestClient::Resource.new("http://#{@host}:#{@port}/submit_job")
    resource.post(job_json)
  end
end
