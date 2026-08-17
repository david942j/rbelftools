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
    # @param [Integer] machine
    #   The machine of the ELF file, which decides what {#type} means.
    def initialize(header, stream, machine: nil)
      @header = header
      @stream = stream
      @machine = machine
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

    def mask_bit
      header.elf_class == 32 ? 8 : 32
    end
  end
end
