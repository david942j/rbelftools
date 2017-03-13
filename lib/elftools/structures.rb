require 'bindata'
module ELFTools
  # ELF header structure.
  class ELF_Ehdr < BinData::Record
    CHOICE_SIZE_T = {
      selection: -> { e_ident.ei_class }, choices: { 1 => :uint32, 2 => :uint64 }
    }.freeze

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
    uint16 :e_ehsize
    uint16 :e_phentsize
    uint16 :e_phnum
    uint16 :e_shentsize
    uint16 :e_shnum
    uint16 :e_shstrndx
  end
end
