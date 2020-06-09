#!/usr/bin/env ruby

class KernelTag
  include Comparable
  attr_reader :kernel_tag

  def initialize(kernel_tag)
    @kernel_tag = kernel_tag
  end

  # Convert kernel_tag to number, major *1000 + minor * 100 + prerelease
  # If kernel is not a rc version. Set prerelease as 99.
  # E.g. kernel_tag: v5.7-rc3 ==> 5 * 10000 + 7 * 100 + 3 = 50703
  # kernel_tag: v5.7 ==> 5 * 10000 + 7 *100 + 99 = 50799
  # kernel_tag: v4.20-rc2 ==> 4 * 10000 + 20 * 100 + 2 = 42002
  def numerize_kernel_tag(kernel_tag)
    match = kernel_tag.match(/v(?<major_version>[0-9])\.(?<minor_version>\d+)\.?(-rc(?<prerelease_version>\d+))?/)
    if match[:prerelease_version]
      prerelease_version = match[:prerelease_version].to_i
    else
      prerelease_version = 99
    end
    match[:major_version].to_i * 10000 + match[:minor_version].to_i * 100 + prerelease_version
  end

  def <=>(other)
    numerized_kernel_version1 = numerize_kernel_tag(@kernel_tag)
    numerized_kernel_version2 = numerize_kernel_tag(other.kernel_tag)

    numerized_kernel_version1 <=> numerized_kernel_version2
  end
end
