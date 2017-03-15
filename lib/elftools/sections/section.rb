require 'elftools/constants'
module ELFTools
  module Sections
    # Base class of sections.
    class Section
      attr_reader :header # @return [ELFTools::ELF_Shdr] Section header.
      attr_reader :stream # @return [File] Streaming object.

      # Instantiate a {Section} object.
      # @param [ELFTools::ELF_Shdr] header
      #   The section header object.
      # @param [File] stream
      #   The streaming object for further dump.
      # @param [ELFTools::Sections::StrTabSection, Proc] strtab
      #   The string table object. For fetching section names.
      #   If +Proc+ if given, it will call at the first
      #   time access +#name+.
      def initialize(header, stream, strtab: nil, **_kwagrs)
        @header = header
        @stream = stream
        @strtab = strtab
      end

      # Get name of this section.
      # @return [String] The name.
      def name
        @name ||= @strtab.call.name_at(header.sh_name)
      end

      # Fetch data of this section.
      # @return [String] Data.
      def data
        stream.pos = header.sh_offset
        stream.read(header.sh_size)
      end

      # Is this a null section?
      # @return [Boolean] No it's not.
      def null?
        false
      end
    end
  end
end
