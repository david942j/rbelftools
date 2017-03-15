require 'bindata'
module ELFTools
  # The base structure to define common methods.
  class ELFStruct < BinData::Record
    CHOICE_SIZE_T = {
      selection: :elf_class, choices: { 32 => :uint32, 64 => :uint64 }
    }.freeze

    attr_accessor :elf_class # @return [Integer] 32 or 64.

    # Hacking to get endian of current class
    # @return [Symbol, NilClass] +:little+ or +:big+.
    def self.self_endian
      bindata_name[-2..-1] == 'ge' ? :big : :little
    end
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

  # Program header structure for 32bit.
  class ELF32_Phdr < ELFStruct
    endian :big_and_little
    uint32 :p_type
    uint32 :p_offset
    uint32 :p_vaddr
    uint32 :p_paddr
    uint32 :p_filesz
    uint32 :p_memsz
    uint32 :p_flags
    uint32 :p_align
  end

  # Program header structure for 64bit.
  class ELF64_Phdr < ELFStruct
    endian :big_and_little
    uint32 :p_type
    uint32 :p_flags
    uint64 :p_offset
    uint64 :p_vaddr
    uint64 :p_paddr
    uint64 :p_filesz
    uint64 :p_memsz
    uint64 :p_align
  end
  ELF_Phdr = {
    32 => ELF32_Phdr,
    64 => ELF64_Phdr
  }.freeze

  # Symbol structure for 32bit.
  class ELF32_sym < ELFStruct
    endian :big_and_little
    uint32 :st_name
    uint32 :st_value
    uint32 :st_size
    uint8 :st_info
    uint8 :st_other
    uint16 :st_shndx
  end

  # Symbol structure for 64bit.
  class ELF64_sym < ELFStruct
    endian :big_and_little
    uint32 :st_name  # Symbol name, index in string tbl
    uint8 :st_info   # Type and binding attributes
    uint8 :st_other  # No defined meaning, 0
    uint16 :st_shndx # Associated section index
    uint64 :st_value # Value of the symbol
    uint64 :st_size  # Associated symbol size
  end
  ELF_sym = {
    32 => ELF32_sym,
    64 => ELF64_sym
  }.freeze

  # Note header.
  class ELF_Nhdr < ELFStruct
    endian :big_and_little
    uint32 :n_namesz # Name size
    uint32 :n_descsz # Content size
    uint32 :n_type   # Content type
  end

  # Dynamic tag header.
  class ELF_Dyn < ELFStruct
    endian :big_and_little
    choice :d_tag, selection: :elf_class, choices: { 32 => :int32, 64 => :int64 }
    # This is an union type named +d_un+ in original source,
    # simplify it to be +d_val+ here.
    choice :d_val, **CHOICE_SIZE_T
  end
end
