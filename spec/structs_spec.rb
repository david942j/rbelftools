# frozen_string_literal: true

require 'stringio'

require 'elftools/elf_file'

describe ELFTools::Structs::ELFStruct do
  def header(name = 'amd64.elf')
    ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name))).header
  end

  describe 'patches' do
    it 'reports nothing while nothing has changed' do
      expect(header.patches).to eq({})
    end

    it 'reports a field however deeply it is nested' do
      hdr = header
      # EI_ABIVERSION is the ninth byte of what e_ident records, and e_ident is
      # a structure of its own, which nothing used to be able to patch.
      hdr.e_ident.ei_abiversion = 41
      expect(hdr.patches).to eq({ 8 => 41.chr })
    end

    it 'reports nothing for a field assigned what it already held' do
      hdr = header
      hdr.e_machine = ELFTools::Constants::EM_ARM
      hdr.e_machine = ELFTools::Constants::EM_X86_64
      expect(hdr.patches).to eq({})
    end

    it 'reports each run of changed bytes on its own' do
      hdr = header
      hdr.e_ident.ei_osabi = 3
      hdr.e_machine = ELFTools::Constants::EM_ARM
      expect(hdr.patches).to eq({ 7 => 3.chr, 18 => 40.chr })
    end

    it 'orders the bytes the way the file it was read from does' do
      # The same assignment, of a number whose halves differ, reaches a
      # different byte of the field in a file ordered the other way.
      expect(header('amd64.elf').tap { |hdr| hdr.e_machine = 40 }.patches).to eq({ 18 => 40.chr })
      expect(header('ppc64.elf').tap { |hdr| hdr.e_machine = 40 }.patches).to eq({ 19 => 40.chr })
    end

    it 'reports a change to the last field of a structure' do
      # Nothing is compared past where the bytes a structure was read from
      # reach, so the last field is the one a source short of the structure
      # would drop.
      hdr = header
      hdr.e_shstrndx = 0x0102
      expect(hdr.patches).to eq({ 62 => "\x02\x01" })
    end

    it 'reports nothing for a structure that was never read' do
      expect(ELFTools::Structs::ELF_Dyn.new(endian: :little).patches).to eq({})
    end
  end

  describe '.unpack_fields' do
    # Which structure a table records, for the tables elftools reads entry by
    # entry.
    def entry_class(section, elf)
      case section.header.sh_type.to_i
      when ELFTools::Constants::SHT_SYMTAB, ELFTools::Constants::SHT_DYNSYM
        ELFTools::Structs::ELF_sym[elf.elf_class]
      when ELFTools::Constants::SHT_REL then ELFTools::Structs::ELF_Rel
      when ELFTools::Constants::SHT_RELA then ELFTools::Structs::ELF_Rela
      when ELFTools::Constants::SHT_DYNAMIC then ELFTools::Structs::ELF_Dyn
      end
    end

    # What the structure reads from the same bytes, which is what the file
    # says they hold.
    def read_with_bindata(klass, bytes, elf)
      struct = klass.new(endian: elf.endian)
      struct.elf_class = elf.elf_class
      struct.read(StringIO.new(bytes))
      struct.snapshot
    end

    it 'reads what the structure reads, of either class and in either order' do
      read = 0
      %w[amd64.elf i386.elf arm.elf mips.o mips64.o ppc64.elf riscv64.elf aarch64.elf libc.so.6].each do |name|
        elf = ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name)))
        elf.sections.each do |section|
          klass = entry_class(section, elf)
          next if klass.nil?

          entsize = section.header.sh_entsize.to_i
          (section.header.sh_size.to_i / entsize).times do |n|
            elf.stream.pos = section.header.sh_offset.to_i + (n * entsize)
            bytes = elf.stream.read(klass.num_bytes(elf_class: elf.elf_class, endian: elf.endian))
            expect(klass.unpack_fields(bytes, elf_class: elf.elf_class, endian: elf.endian))
              .to eq read_with_bindata(klass, bytes, elf)
            read += 1
          end
        end
      end
      # Symbols, relocations of both kinds, and tags, of both classes and both
      # byte orders.
      expect(read).to be > 1000
    end

    it 'reads a field recording a sign as one, and one recording none as none' do
      # An addend is the one field of a relocation that records a sign, so
      # every bit of it set is -1 where the same bits of an offset are not.
      rela = ELFTools::Structs::ELF_Rela
      expect(rela.unpack_fields("\xff" * 24, elf_class: 64, endian: :little))
        .to eq({ r_offset: 0xffff_ffff_ffff_ffff, r_info: 0xffff_ffff_ffff_ffff, r_addend: -1 })
      expect(rela.unpack_fields([8, 5, -16].pack('Q<Q<q<'), elf_class: 64, endian: :little))
        .to eq({ r_offset: 8, r_info: 5, r_addend: -16 })
      expect(rela.unpack_fields([8, 5, -16].pack('Q>Q>q>'), elf_class: 64, endian: :big))
        .to eq({ r_offset: 8, r_info: 5, r_addend: -16 })
      # A tag records one as well, of a width the class of the file decides.
      expect(ELFTools::Structs::ELF_Dyn.unpack_fields([-3, 9].pack('l<L<'), elf_class: 32, endian: :little))
        .to eq({ d_tag: -3, d_val: 9 })
    end

    it 'reports a structure that is not one of integers' do
      # e_ident is a structure of its own, which nothing here unpacks.
      expect { ELFTools::Structs::ELF_Ehdr.unpack_fields('x' * 64, elf_class: 64, endian: :little) }
        .to raise_error(ELFTools::ELFError, 'ELFTools::Structs::ELF_Ehdr is not a structure of integers')
    end
  end

  describe '.num_bytes' do
    it 'is how many bytes a structure of the kind takes' do
      expect(ELFTools::Structs::ELF32_sym.num_bytes(elf_class: 32, endian: :little)).to be 16
      expect(ELFTools::Structs::ELF64_sym.num_bytes(elf_class: 64, endian: :big)).to be 24
      # The fields recording an address are as wide as the class of the file.
      expect(ELFTools::Structs::ELF_Rela.num_bytes(elf_class: 32, endian: :little)).to be 12
      expect(ELFTools::Structs::ELF_Rela.num_bytes(elf_class: 64, endian: :little)).to be 24
    end
  end

  describe '.pack' do
    it 'packs an integer the way the class it is asked of is ordered' do
      expect(ELFTools::Structs::ELF_DynLe.pack(0x0102, 2)).to eq "\x02\x01".b
      expect(ELFTools::Structs::ELF_DynBe.pack(0x0102, 2)).to eq "\x01\x02".b
      expect { ELFTools::Structs::ELF_DynLe.pack('x', 2) }
        .to raise_error(ArgumentError, 'Not supported assign type String')
    end
  end
end
