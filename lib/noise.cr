#!/usr/bin/env crystal

# NOISE_....].freeze
NOISE_LEVELS = [100, 75, 50, 25, 5, 2]

SCALE = 100_000

class Noise
  def initialize(str : String,data : Array(Int32), scale = SCALE)
    @data = data 
    @min = @max = @med = @samples = 0
    @noise_levels = [] of String
    @str = str
    @scale = scale
  end

  def analyse
    @data.sort!
    @data.reverse!

    @med = @data[(@data.size / 2).to_i].to_i
    @max = @data.first
    @min = @data.last

    @data.map! { |d| d - @med }

    @samples = @data.size
    start = 0
    cycles = 0
    #@noise_levels=...._index.map do
    # @noise_levels=NOISE_LEVELS.each_with_index
    #@noise_levels = NOISE_LEVELS.each_with_index do |level, _i|
    NOISE_LEVELS.each_with_index do |level,_i|
      lnt = @med * level / 100
      nstart = @data.index { |n| n < lnt }
      nstart ||= @samples
      (start...nstart).each { |di| cycles += @data[di] }
      start = nstart
      [level, cycles]
    end
  end

  def log
    printf "%s.max: %d\n", @str, @max
    printf "%s.min: %d\n", @str, @min
    printf "%s.med: %d\n", @str, @med
    # @noise_levels.each do |level, mc|
    NOISE_LEVELS.each_with_index do |level,mc|
      printf "%s.noise.%d%%: %d\n", @str, level, mc * @scale / @samples
    end
  end
end
