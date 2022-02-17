# frozen_string_literal: true

require 'rest-client'
require_relative './unit'

# scheduler client class
class SchedulerClient
  def initialize(host = '172.17.0.1', port = 3000)
    @host = host
    @port = port
    @url_prefix = url_prefix
  end

  def submit_job(job_json)
    resource = RestClient::Resource.new("#{@url_prefix}#{@host}:#{@port}/submit_job")
    resource.post(job_json)
  end

  def cancel_jobs(content)
    resource = RestClient::Resource.new("#{@url_prefix}#{@host}:#{@port}/cancel_jobs")
    resource.post(content)
  end

  def renew_deadline(job_id, time)
    resource = RestClient::Resource.new(
      "#{@url_prefix}#{@host}:#{@port}/renew_deadline?job_id=#{job_id}&time=#{to_seconds(time)}")
    resource.get
  end

  def get_deadline(testbox)
    resource = RestClient::Resource.new(
      "#{@url_prefix}#{@host}:#{@port}/get_deadline?testbox=#{testbox}")
    resource.get
  end

  private def url_prefix
    if @host.match('.*[a-zA-Z]+.*')
      # Internet users should use domain name and https
      @url_prefix = 'https://'
    else
      # used in intranet for now
      @url_prefix = 'http://'
    end
  end
end

class DataApiClient < SchedulerClient
  def es_search(index, request_json)
    resource = RestClient::Resource.new("#{@url_prefix}#{@host}:#{@port}/data_api/es/#{index}/_search")
    resource.post(request_json)
  end

  def es_opendistro_sql(request_json)
    resource = RestClient::Resource.new("#{@url_prefix}#{@host}:#{@port}/data_api/_opendistro/_sql")
    resource.post(request_json)
  end
end
