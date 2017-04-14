# Enhancement to enumerable and enumerator

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath(__FILE__)))

module Enumerable
  def feach(func)
    block_given? or return enum_for(__method__, func)

    each { |*args|
      func.call(*args)
      yield *args
    }
  end

  def fmap(func)
    block_given? or return enum_for(__method__, func)

    each { |*args|
      yield func.call(*args)
    }
  end

  def fselect(func, &b)
    block_given? or return enum_for(__method__, func)

    each { |*args|
      yield *args if func.call(*args)
    }
  end

  def fchain(func, &b)
    block_given? or return enum_for(__method__, func)

    each { |*args|
      func.call(*args, &b)
    }
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
    @enumerators.each { |enum|
      enum.each(&b)
    }
  end
end
