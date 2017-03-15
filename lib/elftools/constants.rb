module ELFTools
  # Define constants from elf.h.
  # Mostly refer from [here](https://github.com/torvalds/linux/blob/master/include/uapi/linux/elf.h).
  module Constants
    # ELF magic header
    ELFMAG = "\x7FELF".freeze

    # section types, records in +sh_type+
    module SHT
      SHT_NULL     = 0
      SHT_PROGBITS = 1
      SHT_SYMTAB   = 2
      SHT_STRTAB   = 3
      SHT_RELA     = 4
      SHT_HASH     = 5
      SHT_DYNAMIC  = 6
      SHT_NOTE     = 7
      SHT_NOBITS   = 8
      SHT_REL      = 9
      SHT_SHLIB    = 10
      SHT_DYNSYM   = 11
      SHT_NUM      = 12
      SHT_LOPROC   = 0x70000000
      SHT_HIPROC   = 0x7fffffff
      SHT_LOUSER   = 0x80000000
      SHT_HIUSER   = 0xffffffff
    end
    include SHT

    # segment types, records in +p_type+
    module PT
      PT_NULL         = 0
      PT_LOAD         = 1
      PT_DYNAMIC      = 2
      PT_INTERP       = 3
      PT_NOTE         = 4
      PT_SHLIB        = 5
      PT_PHDR         = 6
      PT_TLS          = 7          # Thread local storage segment
      PT_LOOS         = 0x60000000 # OS-specific
      PT_HIOS         = 0x6fffffff # OS-specific
      PT_LOPROC       = 0x70000000
      PT_HIPROC       = 0x7fffffff
      PT_GNU_EH_FRAME = 0x6474e550
      PT_GNU_STACK    = (PT_LOOS + 0x474e551)
    end
    include PT
  end
end
