module ELFTools
  module Segments
    # Base class of segments.
    class Segment
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
end
