# frozen_string_literal: true

require 'elftools/constants'
module ELFTools
  module Sections
    # Base class of sections.
    class Section
      attr_reader :header # @return [ELFTools::Structs::ELF_Shdr] Section header.
      attr_reader :stream # @return [#pos=, #read] Streaming object.
      attr_writer :data
      attr_accessor :index

      # Instantiate a {Section} object.
      # @param [ELFTools::Structs::ELF_Shdr] header
      #   The section header object.
      # @param [#pos=, #read] stream
      #   The streaming object for further dump.
      # @param [ELFTools::Sections::StrTabSection, Proc] strtab
      #   The string table object. For fetching section names.
      #   If +Proc+ if given, it will call at the first
      #   time access +#name+.
      # @param [Method] offset_from_vma
      #   The method to get offset of file, given virtual memory address.
      def initialize(header, stream, offset_from_vma: nil, strtab: nil, **_kwargs)
        @header = header
        @stream = stream
        @strtab = strtab
        @offset_from_vma = offset_from_vma
        @data = nil
      end

      # Return +header.sh_type+ in a simplier way.
      # @return [Integer]
      #   The type, meaning of types are defined in {Constants::SHT}.
      def type
        header.sh_type.to_i
      end

      # Get name of this section.
      # @return [String] The name.
      def name
        @name ||= @strtab.call.name_at(header.sh_name)
      end

      # Fetch data of this section.
      # @return [String] Data.
      def data
        unless @data
          stream.pos = header.sh_offset
          @data = stream.read(header.sh_size).force_encoding('ascii-8bit')
        end
        @data
      end

      # Is this a null section?
      # @return [Boolean] No it's not.
      def null?
        false
      end

      def size
        data.size
      end

      def size=(size)
        throw ArgumentError.new('new size is negative') if size.negative?
        size -= data.size
        if size.positive?
          @data += '\0' * size
        elsif size.negative?
          @data = @data[0...size]
        end
        @data.size
      end

      def rebuild
        header.sh_size = data.size
        @data
      end
    end
  end
end
