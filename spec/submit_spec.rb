require 'spec_helper'
require "#{LKP_SRC}/lib/yaml"

def stable_yaml_file(yaml_file)
  job = load_yaml(yaml_file)
  delete_job_key = %w(LKP_DEBUG_PREFIX lkp_initrd_user job_origin)
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

def submit_job(submit_item)
  submit_yaml_path = File.join("#{LKP_SRC}/spec/submit", submit_item)
  Dir.glob("#{submit_yaml_path}/*.yaml").each do |yaml_file|
  output_dir = File.join(submit_yaml_path, File.basename(yaml_file, '.yaml'))
    submit_cmd = [
      "#{LKP_SRC}/sbin/submit",
      '-o', output_dir,
      '-s', 'lab: spec_lab',
      '-s', 'testbox: vm-2p8g--spec_submit',
      yaml_file
    ]
    system(*submit_cmd)
    traverse_file(output_dir)
  end
end

describe 'submit job spec' do
  it 'link jobs spec' do
    submit_job('link_jobs')
  end

  it 'link matrix' do
    submit_job('matrix')
  end

  it 'separate yaml spec' do
    submit_job('separate_yaml')
  end
end
