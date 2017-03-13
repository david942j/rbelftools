module ELFTools
  # Define constants from elf.h.
  # Mostly refer from [here](https://github.com/torvalds/linux/blob/master/include/uapi/linux/elf.h).
  module Constants
    # ELF magic header
    ELFMAG = "\x7FELF".freeze

    # sh_type
    SHT_NULL = 0
    SHT_PROGBITS = 1
    SHT_SYMTAB = 2
    SHT_STRTAB = 3
    SHT_RELA = 4
    SHT_HASH = 5
    SHT_DYNAMIC = 6
    SHT_NOTE = 7
    SHT_NOBITS = 8
    SHT_REL = 9
    SHT_SHLIB = 10
    SHT_DYNSYM = 11
    SHT_NUM = 12
    SHT_LOPROC = 0x70000000
    SHT_HIPROC = 0x7fffffff
    SHT_LOUSER = 0x80000000
    SHT_HIUSER = 0xffffffff
  end
end
