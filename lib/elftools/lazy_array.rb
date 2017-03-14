module ELFTools
  # A helper class for {ELFTools} easy to implement
  # 'lazy loading' objects.
  # Mainly useful for loading sections, segments, and
  # symbols.
  class LazyArray
    # Instantiate a {LazyArray} object.
    # @param [Integer] size
    #   The size of array.
    # @param [Block] block
    #   At first time accessing +i+-th element,
    #   Block will be called as +block.call(i)+.
    # @example
    #   arr = LazyArray.new(10) { |i| p i; i * i }
    #   p arr[2]
    #   # 2
    #   # 4
    #
    #   p arr[3]
    #   # 3
    #   # 9
    #
    #   p arr[3]
    #   # 9
    def initialize(size, &block)
      @internal = Array.new(size)
      @block = block
    end

    # To access elements like a normal array.
    #
    # Elements are lazy loaded at the first time
    # access it.
    # @return [Object]
    #   The element, returned type is the
    #   return type of block given in {#initialize}.
    def [](i)
      # XXX: support negative index?
      return nil if i < 0 || i >= @internal.size
      @internal[i] ||= @block.call(i)
    end
  end
end
