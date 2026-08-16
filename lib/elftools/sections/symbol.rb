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
    end
  end
end
