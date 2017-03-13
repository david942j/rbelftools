module ELFTools
  # Base class of segments.
  class Segment
    attr_reader :header # @return [ELFTools::ELF32_Phdr, ELFTools::ELF64_Phdr] Segment header.
    attr_reader :stream # @return [File] Streaming object.

    # Instantiate a {Segment} object.
    # @param [ELFTools::ELF32_Phdr, ELFTools::ELF64_Phdr] header
    #   Segment header.
    # @param [File] stream
    #   Streaming object.
    def initialize(header, stream)
      @header = header
      @stream = stream
    end

    def data
      stream.pos = header.p_offset
      stream.read(header.p_filesz)
    end
  end
end
