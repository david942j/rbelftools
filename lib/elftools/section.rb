require 'elftools/constants'
module ELFTools
  # Base class of sections.
  class Section
    # Class methods.
    class << self
      # Use different class according to +header.sh_type+.
      # @param [ELFTools::ELF_Shdr] header Section header.
      # @param [File] stream Streaming object.
      # @return [ELFTools::Section]
      #   Return object dependes on +header.sh_type+.
      def create(header, stream, *args)
        klass = case header.sh_type
                when Constants::SHT_NULL then NullSection
                when Constants::SHT_SYMTAB, Constants::SHT_DYNSYM then SymTabSection
                when Constants::SHT_STRTAB then StrTabSection
                else Section
                end
        klass.new(header, stream, *args)
      end
    end
    attr_reader :header # @return [ELFTools::ELF_Shdr] Section header.
    attr_reader :stream # @return [File] Streaming object.

    # Instantiate a {Section} object.
    # @param [ELFTools::ELF_Shdr] header
    #   The section header object.
    # @param [File] stream
    #   The streaming object for further dump.
    # @param [ELFTools::StrTabSection, Proc] strtab
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

    def null?
      false
    end
  end

  # Class of null section.
  # Null section is for specific the end
  # of linked list(+sh_link+) between sections.
  class NullSection < Section
    def null?
      true
    end
  end

  # Class of string table section.
  # Usually for section .strtab and .dynstr,
  # which record names.
  class StrTabSection < Section
    # Return the section or symbol name.
    # @param [Integer] offset
    #   Usually from +shdr.sh_name+ or +sym.st_name+.
    # @return [String] The name without null bytes.
    def name_at(offset)
      stream.pos = header.sh_offset + offset
      # read until "\x00"
      ret = ''
      loop do
        c = stream.read(1)
        return nil if c.nil? # reach EOF
        break if c == "\x00"
        ret += c
      end
      ret
    end
  end

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
    # @return [ELFTools:Symbol, NilClass]
    #   The target symbol.
    #   If +n >= num_symbols+, +nil+ is returned.
    def symbol_at(n)
      return if n >= num_symbols
      @symbols ||= Array.new(num_symbols)
      @symbols[n] ||= create_symbol(n)
    end

    def symbols
      Array.new(num_symbols) { |n| symbol_at(n) }
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
      # TODO: fetch endian from header
      sym = ELF_sym[header.elf_class].new(endian: :little)
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
