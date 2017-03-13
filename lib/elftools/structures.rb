require 'bindata'
module ELFTools
  # The base structure to define common methods.
  class ELFStruct < BinData::Record
    CHOICE_SIZE_T = {
      selection: -> { elf_class }, choices: { 32 => :uint32, 64 => :uint64 }
    }.freeze

    attr_accessor :elf_class # @return [Integer] 32 or 64.
  end

  # ELF header structure.
  class ELF_Ehdr < ELFStruct
    endian :big_and_little
    struct :e_ident do
      string :magic, read_length: 4
      int8 :ei_class
      int8 :ei_data
      int8 :ei_version
      int8 :ei_osabi
      int8 :ei_abiversion
      string :ei_padding, read_length: 7 # no use
    end
    uint16 :e_type
    uint16 :e_machine
    uint32 :e_version
    # entry point
    choice :e_entry, **CHOICE_SIZE_T
    choice :e_phoff, **CHOICE_SIZE_T
    choice :e_shoff, **CHOICE_SIZE_T
    uint32 :e_flags
    uint16 :e_ehsize # size of this header
    uint16 :e_phentsize # size of each segment
    uint16 :e_phnum # number of segments
    uint16 :e_shentsize # size of each section
    uint16 :e_shnum # number of sections
    uint16 :e_shstrndx # index of string table section
  end

  # Section header structure.
  class ELF_Shdr < ELFStruct
    endian :big_and_little
    uint32 :sh_name
    uint32 :sh_type
    choice :sh_flags, **CHOICE_SIZE_T
    choice :sh_addr, **CHOICE_SIZE_T
    choice :sh_offset, **CHOICE_SIZE_T
    choice :sh_size, **CHOICE_SIZE_T
    uint32 :sh_link
    uint32 :sh_info
    choice :sh_addralign, **CHOICE_SIZE_T
    choice :sh_entsize, **CHOICE_SIZE_T
  end
end
