# frozen_string_literal: true

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
    def initialize(header, stream)
      @header = header
      @stream = stream
    end

    # +r_info+ contains sym and type, use two methods
    # to access them easier.
    # @return [Integer] The symbol index.
    def r_info_sym
      header.r_info >> mask_bit
    end
    alias symbol_index r_info_sym

    # +r_info+ contains sym and type, use two methods
    # to access them easier.
    # @return [Integer] The relocation type.
    def r_info_type
      header.r_info & ((1 << mask_bit) - 1)
    end
    alias type r_info_type

    private

    def mask_bit
      header.elf_class == 32 ? 8 : 32
    end
  end
end
