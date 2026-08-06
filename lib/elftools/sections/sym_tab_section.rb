# frozen_string_literal: true

require 'elftools/sections/section'
require 'elftools/enums'

module ELFTools
  module Sections
    # Class of symbol table section.
    # Usually for section .symtab and .dynsym,
    # which will refer to symbols in ELF file.
    class SymTabSection < Section
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
        @symbols[n]&.tap { |sym| sym.index = n }
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
        @symstr ||= elf.section_at(header.sh_link)
      end

      # Regenereates section's data to be saved in a rebuilt file.
      # @return [String] Binary representation of section data
      def rebuild
        @data = ''
        each_symbols do |s|
          @data += s.header.to_binary_s
        end

        header.sh_info = symbols.index { |s| s.st_bind == Symbol::Bind.GLOBAL } || num_symbols

        super
      end

      # Appends new symbol to the section.
      # Requires ELFFile rebuild to save changes.
      #
      # @param [Symbol::Type] type Symbol type, stored in header's st_info
      # @param [String] name Symbol name, added to ".strtab" section if needed
      # @param [Symbol::Visibility] vis Symbol visibility, stored in header's st_other
      # @param [Symbol::Bind] vis Symbol scope, stored in header's st_info
      # @return [Symbol]
      def append(type:, name: '', vis: Symbol::Visibility.DEFAULT, bind: Symbol::Bind.LOCAL)
        hdr = Structs::ELF_sym[elf_class].new(endian: header.class.self_endian)
        hdr.elf_class = elf_class
        hdr.st_name = elf.strtab.find_or_insert(name)

        sym = Symbol.new(hdr, stream, self)

        sym.st_bind = bind
        sym.st_type = type
        sym.st_vis = vis
        sym.index = num_symbols

        @symbols ||= LazyArray.new(num_symbols, &method(:create_symbol))
        @symbols.push(sym)
        self.data += sym.header.to_binary_s
        header.sh_size += header.sh_entsize

        sym
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
      attr_accessor :index # @return [ELFTools::Sections::SymTabSection] Section containing the symbol.

      # Instantiate a {ELFTools::Sections::Symbol} object.
      # @param [ELFTools::Structs::ELF32_sym, ELFTools::Structs::ELF64_sym] header
      #   The symbol header.
      # @param [#pos=, #read] stream The streaming object.
      # @param [ELFTools::Sections::SymTabSection, Proc] section
      #   The section containing this symbol, available for later access with {Symbol#section}.
      def initialize(header, stream, section)
        raise ArgumentError, 'Invalid section' unless section.is_a? Section

        @header = header
        @stream = stream
        # Proc wrapper used for {ELFFile#loaded_headers} to work
        @section = section && -> { section }
      end

      # Returns section containing the symbol.
      # @return [ELFTools::Sections::SymTabSection] section
      def section
        @section.call
      end

      # Return the symbol name.
      # @return [String] The name.
      def name
        @name ||= @symstr.call.name_at(header.st_name)
      end

      # Reads the symbol data from text section at st_shndx.
      # @return [String] symbol data
      def data
        @data ||= section.elf.section_at(header.st_shndx).data[header.st_value, header.st_size]
      end
    end
  end
end
