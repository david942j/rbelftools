# frozen_string_literal: true

require 'elftools/constants'

module ELFTools
  # A relocation entry.
  #
  # Can be either a REL or RELA relocation.
  class Relocation
    attr_reader :header # @return [ELFTools::Structs::ELF_Rel, ELFTools::Structs::ELF_Rela] Rel(a) header.
    attr_reader :stream # @return [#pos=, #read] Streaming object.

    # Instantiate a {Relocation} object.
    # @param [ELFTools::Structs::ELF_Rel, ELFTools::Structs::ELF_Rela] header
    #   The relocation header.
    # @param [#pos=, #read] stream The streaming object.
    # @param [Integer] machine
    #   The machine of the ELF file, which decides what {#type} means and how
    #   {#header} records it.
    def initialize(header, stream, machine: nil)
      @header = header
      @stream = stream
      @machine = machine
    end

    # Which symbol this relocation is against, as an index into the symbol
    # table.
    # @return [Integer] The symbol index.
    def symbol_index
      sym_and_type.first
    end

    # What this relocation does, which only means something together with the
    # machine of the file. {#type_name} names it.
    # @return [Integer] The relocation type.
    def type
      sym_and_type.last
    end

    # The name of {#type}.
    #
    # Every architecture numbers relocation types on its own, so the name is
    # only known when the machine of the file is.
    # @return [String] The name.
    # @example
    #   relocation.type_name
    #   #=> 'R_X86_64_JUMP_SLOT'
    def type_name
      Constants::R.mapping(@machine, type)
    end

    private

    # What +r_info+ records, i.e. a symbol index and a relocation type. Most
    # machines split the field in half between the two, one lays it out its
    # own way.
    # @return [Array(Integer, Integer)] The symbol index and the type.
    def sym_and_type
      return mips64_sym_and_type if mips64?

      [header.r_info >> mask_bit, header.r_info & ((1 << mask_bit) - 1)]
    end

    # Whether the file records relocations the way the 64-bit MIPS ABI does,
    # which is the one layout that departs from halving +r_info+.
    # @return [Boolean] The answer.
    def mips64?
      @machine == Constants::EM_MIPS && header.elf_class == 64
    end

    # Reads +r_info+ as the 64-bit MIPS ABI records it, i.e. a symbol index of
    # four bytes followed by four bytes the ABI keeps for itself, the last of
    # which is the type reported here. Those bytes are ordered as the rest of
    # the file is, which is why the two ends of the field swap places.
    # @example
    #   # A big endian file records the symbol index first,
    #   #   00 00 00 08 | 00    05     18     07
    #   #   sym         | ssym  type3  type2  type
    #   0x0000000800051807 #=> [8, 7]
    #   # a little endian one records the very same relocation as
    #   0x0718050000000008 #=> [8, 7]
    # @return [Array(Integer, Integer)] The symbol index and the type.
    def mips64_sym_and_type
      info = header.r_info.to_i
      return [info >> 32, info & 0xff] if header.class.self_endian == :big

      [info & 0xffff_ffff, info >> 56]
    end

    def mask_bit
      header.elf_class == 32 ? 8 : 32
    end
  end
end
