require 'elftools/sections/section'

module ELFTools
  # Class of symbol table section.
  # Usually for section .symtab and .dynsym,
  # which will refer to symbols in ELF file.
  class SymTabSection < Section
    # Instantiate a {SymTabSection} object.
    # There's a +section_at+ lambda for {SymTabSection}
    # to easily fetch other sections.
    # @param [ELFTools::ELF_Shdr] header
    #   See {Section#initialize} for more information.
    # @param [File] stream
    #   See {Section#initialize} for more information.
    # @param [Proc] section_at
    #   The method for fetching other sections by index.
    #   This lambda should be {ELFTools::ELFFile#section_at}.
    def initialize(header, stream, section_at: nil, **_kwagrs)
      @section_at = section_at
      # For faster #symbol_by_name
      @symbol_name_map = {}
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
    # @return [ELFTools:Symbol, NilClass]
    #   The target symbol.
    #   If +n+ is out of bound, +nil+ is returned.
    def symbol_at(n)
      @symbols ||= LazyArray.new(num_symbols, &method(:create_symbol))
      @symbols[n]
    end

    # Iterate all symbols.
    #
    # All symbols are lazy loading, the symbol
    # only create whenever accessing it.
    # This method is useful for {#symbol_by_name}
    # since not all symbols need to be created.
    # @param [Block] block
    #   Just like +Array#each+, you can give a block.
    # @return [void, Array<ELFTools::symbol>]
    #   If no block is given, the whole symbols will
    #   be returned.
    #   Otherwise, since symbols are lazy loaded,
    #   the return value is not important.
    def each_symbols
      if block_given?
        num_symbols.times { |i| yield symbol_at(i) }
      else
        Array.new(num_symbols, &method(:symbol_at))
      end
    end

    alias symbols each_symbols

    # Get symbol by it's name.
    # @param [String] name
    #   The name of symbol.
    # @return [ELFTools::Symbol] Desired symbol.
    def symbol_by_name(name)
      return @symbol_name_map[name] if @symbol_name_map[name]
      each_symbols do |symbol|
        @symbol_name_map[symbol.name] = symbol
        return symbol if symbol.name == name
      end
      nil
    end

    # Return the symbol string section.
    # Lazy loaded.
    # @return [ELFTools::StrTabSection] The string table section.
    def symstr
      @symstr ||= @section_at.call(header.sh_link)
    end

    private

    def create_symbol(n)
      stream.pos = header.sh_offset + n * header.sh_entsize
      sym = ELF_sym[header.elf_class].new(endian: header.class.self_endian)
      sym.read(stream)
      Symbol.new(sym, stream, symstr: method(:symstr))
    end
  end

  # Class of symbol.
  # XXX: Should this class be defined in an independent file?
  class Symbol
    attr_reader :header # @return [ELFTools::ELF32_sym, ELFTools::ELF64_sym] Section header.
    attr_reader :stream # @return [File] Streaming object.

    # Instantiate a {ELFTools::Symbol} object.
    # @param [ELFTools::ELF32_sym, ELFTools::ELF64_sym] header
    #   The symbol header.
    # @param [File] stream The streaming object.
    # @param [ELFTools::SymStrSection, Proc] symstr
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
