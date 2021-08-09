LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require "#{LKP_SRC}/lib/yaml"

## load file utilities

# load one file of type yaml
def load_one_yaml(file)
  return {} unless file
  return {} unless File.exist? file

  return load_yaml(file)
end

def load_my_config
  config = {}
  self_config_path = "#{ENV['HOME']}/.config/compass-ci"
  Dir.glob(['/etc/compass-ci/defaults/*.yaml',
            "#{self_config_path}/defaults/*.yaml"]).each do |file|
    config.merge! load_one_yaml(file)
  end

  lab_yaml = File.join(self_config_path, 'include/lab', "#{config['lab']}.yaml")
  config.merge! load_one_yaml(lab_yaml)
end
