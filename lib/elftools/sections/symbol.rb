# frozen_string_literal: true

module ELFTools
  module Sections
    # Class of symbol.
    class Symbol
      attr_reader :header # @return [ELFTools::Structs::ELF32_sym, ELFTools::Structs::ELF64_sym] Section header.
      attr_reader :stream # @return [#pos=, #read] Streaming object.

      # Instantiate a {ELFTools::Sections::Symbol} object.
      # @param [ELFTools::Structs::ELF32_sym, ELFTools::Structs::ELF64_sym] header
      #   The symbol header.
      # @param [#pos=, #read] stream The streaming object.
      # @param [ELFTools::Sections::StrTabSection, Proc] symstr
      #   The symbol string section.
      #   If +Proc+ is given, it will be called at the first time
      #   access {Symbol#name}.
      def initialize(header, stream, symstr: nil)
        @header = header
        @stream = stream
        @symstr = symstr
      end

      # Return the symbol name.
      # @return [String] The name.
      def name
        @name ||= @symstr.call.name_at(header.st_name)
      end

      # What kind of entity this symbol refers to.
      #
      # The available types are listed in {ELFTools::Constants::STT}.
      # @return [Integer] The type.
      # @example
      #   symbol.type == ELFTools::Constants::STT_FUNC
      #   #=> true
      def type
        header.st_info & 0xf
      end

      # How this symbol is linked against others with the same name.
      #
      # The available bindings are listed in {ELFTools::Constants::STB}.
      # @return [Integer] The binding.
      # @example
      #   symbol.bind == ELFTools::Constants::STB_GLOBAL
      #   #=> true
      def bind
        header.st_info >> 4
      end

      # How this symbol is accessed once it becomes part of an executable or
      # shared object.
      #
      # The available visibilities are listed in {ELFTools::Constants::STV}.
      # @return [Integer] The visibility.
      # @example
      #   symbol.visibility == ELFTools::Constants::STV_HIDDEN
      #   #=> true
      def visibility
        header.st_other & 0x3
      end

      # The index of the section this symbol is defined in.
      #
      # Values in {ELFTools::Constants::SHN} have special meanings instead of
      # being an index.
      # @return [Integer] The section index.
      # @example
      #   symbol.section_index == ELFTools::Constants::SHN_UNDEF
      #   #=> true # the symbol is undefined and to be resolved at runtime
      def section_index
        header.st_shndx.to_i
      end
    end
  end
end
