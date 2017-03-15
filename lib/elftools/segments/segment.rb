module ELFTools
  # Base class of segments.
  class Segment
    # Class methods.
    class << self
      # Use different class according to +header.p_type+.
      # @param [ELFTools::ELF32_Phdr, ELFTools::ELF64_Phdr] header Program header of a segment.
      # @param [File] stream Streaming object.
      # @return [ELFTools::Segment]
      #   Return object dependes on +header.p_type+.
      def create(header, stream, *args)
        klass = case header.p_type
                when Constants::PT_INTERP then InterpSegment
                when Constants::PT_NOTE then NoteSegment
                else Segment
                end
        klass.new(header, stream, *args)
      end
    end

    attr_reader :header # @return [ELFTools::ELF32_Phdr, ELFTools::ELF64_Phdr] Program header.
    attr_reader :stream # @return [File] Streaming object.

    # Instantiate a {Segment} object.
    # @param [ELFTools::ELF32_Phdr, ELFTools::ELF64_Phdr] header
    #   Program header.
    # @param [File] stream
    #   Streaming object.
    def initialize(header, stream)
      @header = header
      @stream = stream
    end

    # The content in this segment.
    # @return [String] The content.
    def data
      stream.pos = header.p_offset
      stream.read(header.p_filesz)
    end

    # Is this segment readable?
    # @return [Boolean] Ture or false.
    def readable?
      (header.p_flags & 4) == 4
    end

    # Is this segment writable?
    # @return [Boolean] Ture or false.
    def writable?
      (header.p_flags & 2) == 2
    end

    # Is this segment executable?
    # @return [Boolean] Ture or false.
    def executable?
      (header.p_flags & 1) == 1
    end
  end
end
