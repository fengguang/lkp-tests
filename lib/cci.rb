#! /usr/bin/env ruby

# frozen_string_literal: true

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(File.dirname(File.realpath($PROGRAM_NAME))))

require "#{LKP_SRC}/lib/load_file"
require "#{LKP_SRC}/lib/scheduler_client"


def die(msg)
  puts msg
  exit
end

def _alter_field(default_field, field_list)
  custom_field = []
  field_list.each do |field|
    if field.start_with?('-')
      field.sub!(/^-/, '').split(',').each do |f|
        default_field.delete(f)
      end
    elsif field.start_with?('+')
      field.sub!(/^\+/, '').split(',').each do |f|
        default_field << f
      end
    else
      field.split(',').each do |f|
        custom_field << f
      end
    end
  end
  [custom_field, default_field]
end

def merge_field(default_field, field_list)
  return default_field if field_list.empty?

  custom_field, default_field = _alter_field(default_field, field_list)

  if custom_field.empty?
    default_field
  else
    custom_field
  end
end

def get_select_field(field)
  select_field = []
  field.split(',').each do |f|
    select_field << f.strip
  end
  select_field
end

def get_where_list(argv)
  where_list = []
  unless argv.empty?
    argv.each do |a|
      k, v = a.split('=')
      where_list << "#{k}=\'#{v}\'"
    end
  end
  where_list
end

def get_show_type(field, show_type)
  return show_type unless show_type.nil?

  if field == '*'
    'json'
  else
    'array'
  end
end

def get_cci_credentials
  data_hash = {}
  hash = load_my_config
  data_hash['cci_credentials'] = {
    'my_account' => hash['my_account'],
    'my_token' => hash['my_token']
  }

  data_hash['DATA_API_HOST'] ||= hash['DATA_API_HOST'] || hash['SCHED_HOST']
  data_hash['DATA_API_PORT'] ||= hash['DATA_API_PORT'] || '20003'
  
  raise 'Please configure DATA_API_PORT' if data_hash['DATA_API_HOST'].nil?

  return data_hash
end

def es_opendistro_query(data_hash)
  dataapi_client = DataApiClient.new(data_hash['DATA_API_HOST'], data_hash['DATA_API_PORT'])
  response = dataapi_client.es_opendistro_sql(data_hash.to_json)
  response = JSON.parse(response)
  die(response['error_msg']) if response['error_msg']
  response
end
