require 'spec_helper'
require "#{LKP_SRC}/lib/yaml"

def stable_yaml_file(yaml_file)
  job = load_yaml(yaml_file)
  delete_job_key = %w(LKP_DEBUG_PREFIX lkp_initrd_user job_origin my_uuid my_email my_name)
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
    stable_yaml_file(yaml_file) unless File.basename(yaml_file) == 'job.yaml'
  end
end

def submit_job()
  Dir.glob("#{LKP_SRC}/spec/submit/*").each do |output_dir|
    submit_cmd = [
      "#{LKP_SRC}/sbin/submit",
      '-o', output_dir,
      '-s', 'lab: spec_lab',
      '-s', 'testbox: vm-2p8g--spec_submit',
      "#{output_dir}/job.yaml"
    ]
    system(*submit_cmd)
    traverse_file(output_dir)
  end
end

describe 'submit job spec' do
  it 'spec for submit/*/job.yaml' do
    submit_job()
  end
end
