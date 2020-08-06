require 'spec_helper'
require "#{LKP_SRC}/lib/yaml"

def stable_yaml_file(yaml_file)
  job = load_yaml(yaml_file)
  delete_job_key = %w(LKP_DEBUG_PREFIX lkp_initrd_user)
  job.delete_if do |key, _|
    delete_job_key.include?(key) ||
      key.to_s.start_with?('#! ') ||
      key.to_s =~ /_PORT$/ ||
      key.to_s =~ /_HOST$/ ||
      key.to_s =~ /_SERVER$/
  end
  save_yaml(job, yaml_file)
end

def traverse_file(output_dir)
  Dir.glob("#{output_dir}/*.yaml").each do |yaml_file|
    stable_yaml_file(yaml_file)
  end
end

describe 'tj job spec' do
  Dir.glob("#{LKP_SRC}/spec/tj/*.yaml").each do |yaml_file|
    job_name = File.basename(yaml_file, '.yaml')
    output_dir = "#{LKP_SRC}/spec/tj/#{job_name}"
    it 'save atomic yaml' do
      system("#{LKP_SRC}/sbin/tj -o #{output_dir} #{yaml_file}")
      traverse_file(output_dir)
    end
  end
end
