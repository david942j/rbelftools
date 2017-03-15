module ELFTools
  # Define constants from elf.h.
  # Mostly refer from [here](https://github.com/torvalds/linux/blob/master/include/uapi/linux/elf.h).
  module Constants
    # ELF magic header
    ELFMAG = "\x7FELF".freeze

    # Section header types, records in +sh_type+.
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

    # Program header types, records in +p_type+.
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

    # Dynamic table types, records in +d_tag+.
    module DT
      DT_NULL       = 0
      DT_NEEDED     = 1
      DT_PLTRELSZ   = 2
      DT_PLTGOT     = 3
      DT_HASH       = 4
      DT_STRTAB     = 5
      DT_SYMTAB     = 6
      DT_RELA       = 7
      DT_RELASZ     = 8
      DT_RELAENT    = 9
      DT_STRSZ      = 10
      DT_SYMENT     = 11
      DT_INIT       = 12
      DT_FINI       = 13
      DT_SONAME     = 14
      DT_RPATH      = 15
      DT_SYMBOLIC   = 16
      DT_REL        = 17
      DT_RELSZ      = 18
      DT_RELENT     = 19
      DT_PLTREL     = 20
      DT_DEBUG      = 21
      DT_TEXTREL    = 22
      DT_JMPREL     = 23
      DT_ENCODING   = 32
      DT_LOOS       = 0x6000000d
      DT_HIOS       = 0x6ffff000
      DT_VALRNGLO   = 0x6ffffd00
      DT_VALRNGHI   = 0x6ffffdff
      DT_ADDRRNGLO  = 0x6ffffe00
      DT_ADDRRNGHI  = 0x6ffffeff
      DT_VERSYM     = 0x6ffffff0
      DT_RELACOUNT  = 0x6ffffff9
      DT_RELCOUNT   = 0x6ffffffa
      DT_FLAGS_1    = 0x6ffffffb
      DT_VERDEF     = 0x6ffffffc
      DT_VERDEFNUM  = 0x6ffffffd
      DT_VERNEED    = 0x6ffffffe
      DT_VERNEEDNUM = 0x6fffffff
      DT_LOPROC     = 0x70000000
      DT_HIPROC     = 0x7fffffff
    end
    include DT
  end
end
