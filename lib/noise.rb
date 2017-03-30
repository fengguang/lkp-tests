#!/usr/bin/ruby

NOISE_LEVELS = [100, 75, 50, 25, 5, 2]

SCALE = 100000

class Noise
  def initialize str, data, scale=SCALE
    @data = data
    @min = @max = @med = @samples = 0
    @noise_levels = []
    @str = str
    @scale = scale
  end

  def analyse
    @data.sort!
    @data.reverse!

    @med = @data[@data.size / 2]
    @max = @data.first
    @min = @data.last

    @data.map! { |d| d - @med }


    @samples = @data.size
    start = 0
    cycles = 0
    @noise_levels = NOISE_LEVELS.each_with_index.map { |level, i|
      lnt = @med * level / 100
      nstart = @data.find_index { |n| n < lnt }
      nstart ||= @samples
      (start...nstart).each { |di| cycles += @data[di] }
      start = nstart
      [level, cycles]
    }
  end

  def log
    printf "%s.max: %d\n", @str, @max
    printf "%s.min: %d\n", @str, @min
    printf "%s.med: %d\n", @str, @med
    @noise_levels.each { |level, mc|
      printf "%s.noise.%d%%: %d\n", @str, level, mc * @scale / @samples
    }
  end
end
