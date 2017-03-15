module ELFTools
  # Define constants from elf.h.
  # Mostly refer from https://github.com/torvalds/linux/blob/master/include/uapi/linux/elf.h.
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

    # These constants define the various ELF target machines.
    module EM
      EM_NONE           = 0
      EM_M32            = 1
      EM_SPARC          = 2
      EM_386            = 3
      EM_68K            = 4
      EM_88K            = 5
      EM_486            = 6      # Perhaps disused
      EM_860            = 7
      EM_MIPS           = 8      # MIPS R3000 (officially, big-endian only)
      # Next two are historical and binaries and
      # modules of these types will be rejected by Linux.
      EM_MIPS_RS3_LE    = 10     # MIPS R3000 little-endian
      EM_MIPS_RS4_BE    = 10     # MIPS R4000 big-endian

      EM_PARISC         = 15     # HPPA
      EM_SPARC32PLUS    = 18     # Sun's "v8plus"
      EM_PPC            = 20     # PowerPC
      EM_PPC64          = 21     # PowerPC64
      EM_SPU            = 23     # Cell BE SPU
      EM_ARM            = 40     # ARM 32 bit
      EM_SH             = 42     # SuperH
      EM_SPARCV9        = 43     # SPARC v9 64-bit
      EM_H8_300         = 46     # Renesas H8/300
      EM_IA_64          = 50     # HP/Intel IA-64
      EM_X86_64         = 62     # AMD x86-64
      EM_S390           = 22     # IBM S/390
      EM_CRIS           = 76     # Axis Communications 32-bit embedded processor
      EM_M32R           = 88     # Renesas M32R
      EM_MN10300        = 89     # Panasonic/MEI MN10300, AM33
      EM_OPENRISC       = 92     # OpenRISC 32-bit embedded processor
      EM_BLACKFIN       = 106    # ADI Blackfin Processor
      EM_ALTERA_NIOS2   = 113    # Altera Nios II soft-core processor
      EM_TI_C6000       = 140    # TI C6X DSPs
      EM_AARCH64        = 183    # ARM 64 bit
      EM_TILEPRO        = 188    # Tilera TILEPro
      EM_MICROBLAZE     = 189    # Xilinx MicroBlaze
      EM_TILEGX         = 191    # Tilera TILE-Gx
      EM_BPF            = 247    # Linux BPF - in-kernel virtual machine
      EM_FRV            = 0x5441 # Fujitsu FR-V
      EM_AVR32          = 0x18ad # Atmel AVR32

      #  This is an interim value that we will use until the committee comes
      #  up with a final number.
      EM_ALPHA          = 0x9026

      # Bogus old m32r magic number, used by old tools.
      EM_CYGNUS_M32R    = 0x9041
      # This is the old interim value for S/390 architecture
      EM_S390_OLD       = 0xA390
      # Also Panasonic/MEI MN10300, AM33
      EM_CYGNUS_MN10300 = 0xbeef

      # Return the architecture name according to +val+.
      # Used by {ELFTools::ELFFile#machine}.
      #
      # Only supports famous archs.
      # @param [Integer] val Value of +e_machine+.
      # @return [String]
      #   Name of architecture.
      # @example
      #   mapping(3)
      #   #=> 'Intel 80386'
      #   mapping(6)
      #   #=> 'Intel 80386'
      #   mapping(62)
      #   #=> 'Advanced Micro Devices X86-64'
      #   mapping(1337)
      #   #=> '<unknown>: 0x539'
      def self.mapping(val)
        case val
        when EM_NONE then 'None'
        when EM_386, EM_486 then 'Intel 80386'
        when EM_860 then 'Intel 80860'
        when EM_MIPS then 'MIPS R3000'
        when EM_PPC then 'PowerPC'
        when EM_PPC64 then 'PowerPC64'
        when EM_ARM then 'ARM'
        when EM_IA_64 then 'Intel IA-64'
        when EM_AARCH64 then 'AArch64'
        when EM_X86_64 then 'Advanced Micro Devices X86-64'
        else format('<unknown>: 0x%x', val)
        end
      end
    end
    include EM
  end
end
