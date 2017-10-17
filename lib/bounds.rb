#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

def is_valid_stats_range(stats_field, num)
  monitor = stats_field.split('.')[0]
  range_file = "#{LKP_SRC}/etc/valid-range-#{monitor}.yaml"

  $__valid_range_cache ||= {}
  unless $__valid_range_cache.include?(range_file)
    $__valid_range_cache[range_file] = File.exist?(range_file) ? load_json(range_file) : nil
  end

  stats_range = $__valid_range_cache[range_file]

  if stats_range
    stats_range.each do |k, v|
      next unless stats_field =~ %r{^#{k}$}
      min = v[0]
      max = v[1]
      return false if num < min || num > max
    end
  end

  true
end
