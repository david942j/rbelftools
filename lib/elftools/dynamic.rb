module ELFTools
  # Define common methods for dynamic sections and
  # dynamic segments.
  #
  # Notice: this module can only be included by
  # {ELFTools::Sections::DynamicSection} and
  # {ELFTools::Segments::DynamicSegment} because
  # methods here assume some attributes exist.
  module Dynamic
    # Iterate all tags.
    #
    # Notice: this method assume the following methods
    # already exist:
    #   header
    #   tag_start
    # @param [Block] block You can give a block.
    # @return [Array<ELFTools::Dynamic::Tag>] Array of tags.
    def each_tags
      arr = []
      0.step do |i|
        tag = tag_at(i)
        yield tag if block_given?
        arr << tag
        break if tag.header.d_tag == ELFTools::Constants::DT_NULL
      end
      arr
    end
    alias tags each_tags

    # Get a tag of specific type.
    # @param [Integer, Symbol, String] type
    #   Constant value, symbol, or string of type
    #   is acceptable. See examples for more information.
    # @return [ELFTools::Dynamic::Tag] The desired tag.
    # @example
    #   dynamic = elf.segment_by_type(:dynamic)
    #   # type as integer
    #   dynamic.tag_by_type(0) # the null tag
    #   #=>  #<ELFTools::Dynamic::Tag:0x0055b5a5ecad28 @header={:d_tag=>0, :d_val=>0}>
    #   dynamic.tag_by_type(ELFTools::Constants::DT_NULL)
    #   #=>  #<ELFTools::Dynamic::Tag:0x0055b5a5ecad28 @header={:d_tag=>0, :d_val=>0}>
    #
    #   # symbol
    #   dynamic.tag_by_type(:null)
    #   #=>  #<ELFTools::Dynamic::Tag:0x0055b5a5ecad28 @header={:d_tag=>0, :d_val=>0}>
    #   dynamic.tag_by_type(:pltgot)
    #   #=> #<ELFTools::Dynamic::Tag:0x0055d3d2d91b28 @header={:d_tag=>3, :d_val=>6295552}>
    #
    #   # string
    #   dynamic.tag_by_type('null')
    #   #=>  #<ELFTools::Dynamic::Tag:0x0055b5a5ecad28 @header={:d_tag=>0, :d_val=>0}>
    #   dynamic.tag_by_type('DT_PLTGOT')
    #   #=> #<ELFTools::Dynamic::Tag:0x0055d3d2d91b28 @header={:d_tag=>3, :d_val=>6295552}>
    def tag_by_type(type)
      type = Util.to_constant(Constants::DT, type)
      each_tags do |tag|
        return tag if tag.header.d_tag == type
      end
      nil
    end

    # Get the +n+-th tag.
    #
    # Tags are lazy loaded.
    # Notice: this method assume the following methods
    # already exist:
    #   header
    #   tag_start
    #
    # Notice: we cannot do bound checking of +n+ here since
    # the only way to get size of tags is calling +tags.size+.
    # @param [Integer] n The index.
    # @return [ELFTools::Dynamic::Tag] The desired tag.
    def tag_at(n)
      return if n < 0
      @tag_at_map ||= {}
      return @tag_at_map[n] if @tag_at_map[n]
      dyn = Structs::ELF_Dyn.new(endian: endian)
      dyn.elf_class = header.elf_class
      stream.pos = tag_start + n * dyn.num_bytes
      @tag_at_map[n] = Tag.new(dyn.read(stream), stream)
    end

    private

    def endian
      header.class.self_endian
    end

    # A tag class.
    class Tag
      attr_reader :header # @return [ELFTools::ELF_Dyn] The dynamic tag header.
      attr_reader :stream # @return [File] Streaming object.

      # Instantiate a {ELFTools::Dynamic::Tag} object.
      # @param [ELF_Dyn] header The dynamic tag header.
      # @param [File] stream Streaming object.
      def initialize(header, stream)
        @header = header
        @stream = stream
      end
      # TODO: Get the name of tags, e.g. SONAME
      # TODO: Handle (non)-PIE ELF correctly.
    end
  end
end
