# Enhancement to enumerable and enumerator

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

module Enumerable
  def feach(func)
    return enum_for(__method__, func) unless block_given?

    each do |*args|
      func.call(*args)
      yield(*args)
    end
  end

  def fmap(func)
    return enum_for(__method__, func) unless block_given?

    each do |*args|
      yield func.call(*args)
    end
  end

  def fselect(func, &_b)
    return enum_for(__method__, func) unless block_given?

    each do |*args|
      yield(*args) if func.call(*args)
    end
  end

  def fchain(func, &b)
    return enum_for(__method__, func) unless block_given?

    each do |*args|
      func.call(*args, &b)
    end
  end
end

class EnumeratorCollection
  include Enumerable

  def initialize(*enums)
    @enumerators = enums
  end

  def <<(enum)
    @enumerators << enum
    self
  end

  def each(&b)
    @enumerators.each do |enum|
      enum.each(&b)
    end
  end
end
