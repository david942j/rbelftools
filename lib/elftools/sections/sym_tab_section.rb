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
        @symbols[n].tap { |sym| sym.index = n if sym }
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

      class Visibility < Enum
        exclusive true
        enum_attr :default, 0
        enum_attr :internal, 1
        enum_attr :hidden, 2
        enum_attr :protected, 3
        enum_attr :exported, 4
        enum_attr :singleton, 5
        enum_attr :eliminate, 6
      end

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
        @name ||= section.symstr.name_at(header.st_name)
      end

      # Reads the symbol data from text section at st_shndx.
      # @return [String] symbol data
      def data
        @data ||= section.elf.section_at(header.st_shndx).data[header.st_value, header.st_size]
      end

      # Return the symbol bind property.
      # @return [Symbol::Bind] Bind property.
      def st_bind
        Bind.new(header.st_info >> 4)
      end

      # Updates the symbol bind property. Stored in header's st_info high bits.
      # @param [Symbol::Bind, Integer] bind Bind property.
      def st_bind=(bind)
        header.st_info = (header.st_info & 0xf) | (bind.to_i << 4)
      end

      # Return the symbol type property.
      # @return [Symbol::Type] type Type property.
      def st_type
        Type.new(header.st_info & 0xf)
      end

      # Updates the symbol type property. Stored in header's st_info low bits.
      # @param [Symbol::Type, Integer] type Type property.
      def st_type=(type)
        header.st_info = (header.st_info & (~0xf)) | (type.to_i & 0xf)
      end

      # Return the symbol visibility property.
      # @return [Symbol::Visibility] vis Visibility property.
      def st_vis
        Visibility.new(header.st_other & 0x7)
      end

      # Updates the symbol visibility property. Stored in header's st_other.
      # @param [Symbol::Visibility, Integer] vis Visibility property.
      def st_vis=(vis)
        header.st_other = vis.to_i & 0x7
      end
    end
  end
end
