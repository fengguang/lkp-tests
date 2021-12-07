# SPDX-License-Identifier: MulanPSL-2.0+
# Copyright (c) 2020 Huawei Technologies Co., Ltd. All rights reserved.
# frozen_string_literal: true

require_relative './yaml.rb'

# input eg:
# {
#   "submit": [
#     "lmbench3.yaml testbox=taishan200-2280-2s48p-256g--a11 lmbench3.test=lSELECT",
#     "lmbench3.yaml testbox=taishan200-2280-2s48p-256g--a11 lmbench3.test=UNIX",
#     "unixbench.yaml testbox=taishan200-2280-2s48p-256g--a12 runtime=6000"
#     ...
#   ],
#   default_param: {"runtime": 3000},
#   common_param: {
#     "os": [
#       "centos",
#       "openeuler"
#     ],
#     ...
#   }
# }
# return eg:
#   [
#     "runtime=3000 lmbench3.yaml testbox=taishan200-2280-2s48p-256g--a11 os=centos ",
#     "runtime=3000 lmbench3.yaml testbox=taishan200-2280-2s48p-256g--a11 os=openeuler ",
#     ...
#   ]
def gerenate_submit_cmd(args)
  submit_cmds = args['submit'] || nil
  unless submit_cmds || submit_cmds.empty?
    warn 'No submit command!'
    exit
  end

  default_cmds = args['default_param'] || nil
  common_cmds = args['common_param'] || nil
  line_cmds = args["line_param"] || {}

  default_params = parse_commnon_params(default_cmds, line_cmds)
  common_params = parse_commnon_params(common_cmds, line_cmds)
  line_params = parse_commnon_params(line_cmds)

  combine_default_cmds = combine_default_cmd(submit_cmds, default_params)
  combine_cmds = combine_common_cmd(combine_default_cmds, common_params)
  combine_line_cmd(combine_cmds, line_params)
end

def parse_commnon_params(args, needless_param = {})
  return nil unless args
  return nil if args.empty?

  common_params = []
  args.each do |k, v|
    next if needless_param.key?(k)

    assgin_cmd(k, v, common_params)
  end

  common_params
end

def assgin_cmd(key, params, cmd_list)
  if params.is_a?(Array)
    cmds = []
    params.each do |v|
      cmds << "#{key}=#{v}"#{key => v}
    end
    cmd_list << cmds
  elsif params.is_a?(Hash)
    params.each do |k1, v1|
      new_k = key + '.' + k1 if key
      assgin_cmd(new_k, v1, cmd_list)
    end
  else
    cmd_list << "#{key}=#{params}"
  end
end

def combine_default_cmd(submit_cmds, default_params)
  return submit_cmds unless default_params

  combine_cmds = []
  default_cmds = combine_cmd(default_params)
  submit_cmds.each do |submit_cmd|
    default_cmds.each do |default_cmd|
      combine_cmds << default_cmd + submit_cmd
    end
  end

  combine_cmds
end

def combine_common_cmd(submit_cmds, common_params)
  return submit_cmds unless common_params

  combine_cmds = []
  common_cmds = combine_cmd(common_params)

  submit_cmds.each do |submit_cmd|
    submit_a, submit_b = submit_cmd.split('yaml')
    common_cmds.each do |common_cmd|
      combine_cmds << submit_a + 'yaml' + common_cmd + submit_b.to_s
    end
  end

  combine_cmds
end

def combine_line_cmd(submit_cmds, line_params)
  return submit_cmds unless line_params

  combine_cmds = []
  line_cmds = combine_cmd(line_params)

  submit_cmds.each do |submit_cmd|
    line_cmds.each do |line_cmd|
      combine_cmds << submit_cmd + ' ' + line_cmd
    end
  end

  combine_cmds
end

# input eg:
# [
#   "memory=16G", "nr_cpu=2", "runtime=3000",
#   ["os=centos", "os=openeuler"],
#   ...
# ]
def combine_cmd(common_params)
  return nil unless common_params

  common_cmds = [' ']
  common_params.each do |param|
    new_common_cmd = []
    if param.is_a?(String)
      common_cmds.map do |cmd|
        new_common_cmd << cmd + param + ' '
      end
    else
      param.each do |p|
        common_cmds.each do |cmd|
          new_common_cmd << cmd + p + ' '
        end
      end
    end
    common_cmds = new_common_cmd
  end

  common_cmds
end

def parse_batch_argv(argv)
  args = {}
  argv.each do |arg|
    if arg.end_with?('.yaml')
      args.merge!(load_yaml(arg))
      next
    end
    args["line_param"] ||= {}
    key, value = arg.split('=')
    if key && value
      value_list = value.split(',')
      args["line_param"][key] = value_list.length > 1 ? value_list : value
    end
  end

  args
end
