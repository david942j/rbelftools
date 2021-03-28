# frozen_string_literal: true

require 'elftools/sections/section'
require 'elftools/enums'

module ELFTools
  module Sections
    # Class of symbol table section.
    # Usually for section .symtab and .dynsym,
    # which will refer to symbols in ELF file.
    class SymTabSection < Section
      # Instantiate a {SymTabSection} object.
      # There's a +section_at+ lambda for {SymTabSection}
      # to easily fetch other sections.
      # @param [ELFTools::Structs::ELF_Shdr] header
      #   See {Section#initialize} for more information.
      # @param [#pos=, #read] stream
      #   See {Section#initialize} for more information.
      # @param [Proc] section_at
      #   The method for fetching other sections by index.
      #   This lambda should be {ELFTools::ELFFile#section_at}.
      def initialize(header, stream, section_at: nil, **_kwargs)
        @section_at = section_at
        # For faster #symbol_by_name
        super
      end

      # Number of symbols.
      # @return [Integer] The number.
      # @example
      #   symtab.num_symbols
      #   #=> 75
      def num_symbols
        header.sh_size / header.sh_entsize
      end

      # Acquire the +n+-th symbol, 0-based.
      #
      # Symbols are lazy loaded.
      # @param [Integer] n The index.
      # @return [ELFTools::Sections::Symbol, nil]
      #   The target symbol.
      #   If +n+ is out of bound, +nil+ is returned.
      def symbol_at(n)
        @symbols ||= LazyArray.new(num_symbols, &method(:create_symbol))
        @symbols[n]
      end

      # Iterate all symbols.
      #
      # All symbols are lazy loading, the symbol
      # only be created whenever accessing it.
      # This method is useful for {#symbol_by_name}
      # since not all symbols need to be created.
      # @yieldparam [ELFTools::Sections::Symbol] sym A symbol object.
      # @yieldreturn [void]
      # @return [Enumerator<ELFTools::Sections::Symbol>, Array<ELFTools::Sections::Symbol>]
      #   If block is not given, an enumerator will be returned.
      #   Otherwise return array of symbols.
      def each_symbols(&block)
        return enum_for(:each_symbols) unless block_given?

        Array.new(num_symbols) do |i|
          symbol_at(i).tap(&block)
        end
      end

      # Simply use {#symbols} to get all symbols.
      # @return [Array<ELFTools::Sections::Symbol>]
      #   The whole symbols.
      def symbols
        each_symbols.to_a
      end

      # Get symbol by its name.
      # @param [String] name
      #   The name of symbol.
      # @return [ELFTools::Sections::Symbol] Desired symbol.
      def symbol_by_name(name)
        each_symbols.find { |symbol| symbol.name == name }
      end

      # Return the symbol string section.
      # Lazy loaded.
      # @return [ELFTools::Sections::StrTabSection] The string table section.
      def symstr
        @symstr ||= @section_at.call(header.sh_link)
      end

      def section_at(n)
        @section_at[n]
      end

      def resize(n)
        inner = @symbols.instance_variable_get('@internal')
        inner.size = n
      end

      private

      def create_symbol(n)
        stream.pos = header.sh_offset + n * header.sh_entsize
        sym = Structs::ELF_sym[header.elf_class].new(endian: header.class.self_endian, offset: stream.pos)
        sym.read(stream)
        Symbol.new(sym, stream, self)
      end
    end

    # Class of symbol.
    #
    # XXX: Should this class be defined in an independent file?
    class Symbol
      attr_reader :header # @return [ELFTools::Structs::ELF32_sym, ELFTools::Structs::ELF64_sym] Section header.
      attr_reader :stream # @return [#pos=, #read] Streaming object.

      # based on https://docs.oracle.com/cd/E23824_01/html/819-0690/chapter6-79797.html
      class Bind < Enum
        exclusive true
        enum_attr :local, 0
        enum_attr :global, 1
        enum_attr :weak, 2
        enum_attr :loos, 10
        enum_attr :hios, 12
        enum_attr :loproc, 13
        enum_attr :hiproc, 15
      end

      class Type < Enum
        exclusive true
        enum_attr :notype, 0
        enum_attr :object, 1
        enum_attr :func, 2
        enum_attr :section, 3
        enum_attr :file, 4
        enum_attr :common, 5
        enum_attr :tls, 6
        enum_attr :loos, 10
        enum_attr :hios, 12
        enum_attr :sparc_register, 13
        enum_attr :loproc, 13
        enum_attr :hiproc, 15
      end
      # Instantiate a {ELFTools::Sections::Symbol} object.
      # @param [ELFTools::Structs::ELF32_sym, ELFTools::Structs::ELF64_sym] header
      #   The symbol header.
      # @param [#pos=, #read] stream The streaming object.
      # @param [ELFTools::Sections::StrTabSection, Proc] symstr
      #   The symbol string section.
      #   If +Proc+ is given, it will be called at the first time
      #   access {Symbol#name}.
      def initialize(header, stream, section)
        @header = header
        @stream = stream
        @section = -> () { section }
      end

      def section
        @section.call
      end

      # Return the symbol name.
      # @return [String] The name.
      def name
        @name ||= section.symstr.name_at(header.st_name)
      end

      def data
        @data ||= section.section_at(header.st_shndx).data[header.st_value,header.st_size]
      end

      def st_bind
        Bind.new(header.st_info >> 4)
      end

      def st_bind=(bind)
        header.st_info = (header.st_info & 0xf) | (bind.to_i << 4)
      end

      def st_type
        Type.new(header.st_info & 0xf)
      end

      def st_type=(type)
        header.st_info = (header.st_info & (~0xf)) | (type.to_i & 0xf)
      end
    end
  end
end
