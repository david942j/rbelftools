# encoding: ascii-8bit
# frozen_string_literal: true

require 'stringio'
require 'tempfile'

require 'elftools/elf_file'

describe ELFTools::ELFFile do
  before(:all) do
    @filepath = File.join(__dir__, 'files', 'amd64.elf')
    @elf = described_class.new(File.open(@filepath))
  end

  it 'basic' do
    expect(@elf.elf_class).to be 64
    expect(@elf.endian).to be :little
    expect(@elf.machine).to eq 'Advanced Micro Devices X86-64 processor'
  end

  it 'file header' do
    expect(@elf.header.e_ident.magic).to eq "\x7FELF"
    expect(@elf.header.e_ident.ei_version).to eq 1
    expect(@elf.header.e_ident.ei_padding).to eq "\x00" * 7
  end

  describe 'sections' do
    it 'basic' do
      expect(@elf.num_sections).to eq 31
    end

    it 'names' do
      expect(@elf.sections.map(&:name)).to eq [''] + %w[
        .interp .note.ABI-tag .note.gnu.build-id .gnu.hash
        .dynsym .dynstr .gnu.version .gnu.version_r
        .rela.dyn .rela.plt .init .plt .plt.got .text
        .fini .rodata .eh_frame_hdr .eh_frame .init_array
        .fini_array .jcr .dynamic .got .got.plt .data .bss
        .comment .shstrtab .symtab .strtab
      ]

      expect(@elf.section_by_name('.shstrtab')).to be @elf.section_name_table
      expect(@elf.section_by_name('no such section')).to be nil
    end

    it 'data' do
      expect(@elf.section_by_name('.note.gnu.build-id').data)
        .to eq "\x04\x00\x00\x00\x14\x00\x00\x00\x03\x00\x00\x00" \
               "GNU\x00s\xABb\xCB{\xC9\x95\x9C\xE0S\xC2\xB7\x112!Xp\x8C\xDC\a"
    end

    it 'symbols' do
      # symbols from .dynsym
      section = @elf.section_by_name('.dynsym')
      expect(section.symbols.map(&:name)).to eq [''] + %w[
        puts __stack_chk_fail printf __libc_start_main
        fgets __gmon_start__ scanf stdin
      ]

      # symbols from .symtab
      section = @elf.section_by_name('.symtab')
      # Too many symbols, only test non-empty names
      expect(section.symbols.map(&:name).reject(&:empty?)).to eq %w[
        crtstuff.c __JCR_LIST__ deregister_tm_clones register_tm_clones
        __do_global_dtors_aux completed.7588 __do_global_dtors_aux_fini_array_entry
        frame_dummy __frame_dummy_init_array_entry source.cpp _ZZ4funcvE4test
        crtstuff.c __FRAME_END__ __JCR_END__ __init_array_end _DYNAMIC
        __init_array_start __GNU_EH_FRAME_HDR _GLOBAL_OFFSET_TABLE_ __libc_csu_fini
        _ITM_deregisterTMCloneTable data_start puts@@GLIBC_2.2.5 stdin@@GLIBC_2.2.5
        _edata _fini __stack_chk_fail@@GLIBC_2.4 printf@@GLIBC_2.2.5
        __libc_start_main@@GLIBC_2.2.5 fgets@@GLIBC_2.2.5 __data_start
        _Z4funcv __gmon_start__ __dso_handle _IO_stdin_used __libc_csu_init
        _end _start s __bss_start main scanf@@GLIBC_2.2.5 _Jv_RegisterClasses
        __TMC_END__ _ITM_registerTMCloneTable _init
      ]

      # can use 'be' here becauase they should always refer to same object
      expect(section.symbol_by_name('_init')).to be section.symbols.last
    end

    it 'notes' do
      secs = @elf.sections.select { |sec| sec.instance_of?(ELFTools::Sections::NoteSection) }
      # There're two note sections
      expect(secs.size).to be 2
      bid_sec = secs.last
      expect(bid_sec.notes[0].name).to eq 'GNU'
      # The build id
      expect(bid_sec.notes[0].desc.unpack1('H*')).to eq '73ab62cb7bc9959ce053c2b711322158708cdc07'
    end
  end

  describe 'segments' do
    it 'basic' do
      expect(@elf.num_segments).to eq 9
      expect(@elf.segments[1]).to be @elf.segment_at(1)
      expect(@elf.segment_by_type(:phdr).executable?).to be true
      expect(@elf.segment_by_type(:gnu_stack).executable?).to be false
      expect(@elf.segment_by_type(:gnu_stack).writable?).to be true

      expect(@elf.segments_by_type(:load).size).to be 2
    end

    it 'data' do
      expect(@elf.segment_at(1).data).to eq "/lib64/ld-linux-x86-64.so.2\x00"
    end

    it 'interp' do
      expect(@elf.segment_at(1)).to be_a ELFTools::Segments::InterpSegment
      expect(@elf.segment_at(1).interp_name).to eq '/lib64/ld-linux-x86-64.so.2'
    end

    it 'notes' do
      seg = @elf.segment_by_type(ELFTools::Constants::PT_NOTE)
      expect(seg.notes[1].name).to eq 'GNU'
      # The build id
      expect(seg.notes[1].desc.unpack1('H*')).to eq '73ab62cb7bc9959ce053c2b711322158708cdc07'
    end

    it 'segment_by_type' do
      expect(@elf.segment_by_type(ELFTools::Constants::PT_NOTE)).to be_a ELFTools::Segments::NoteSegment
      expect(@elf.segment_by_type(4)).to be_a ELFTools::Segments::NoteSegment
      expect(@elf.segment_by_type(:note)).to be_a ELFTools::Segments::NoteSegment
      expect(@elf.segment_by_type('note')).to be_a ELFTools::Segments::NoteSegment
      expect(@elf.segment_by_type('NoTe')).to be_a ELFTools::Segments::NoteSegment
      expect(@elf.segment_by_type('PT_NOTE')).to be_a ELFTools::Segments::NoteSegment
      expect(@elf.segment_by_type(:PT_NOTE)).to be_a ELFTools::Segments::NoteSegment
      expect { @elf.segment_by_type(1337) }.to raise_error(ArgumentError, 'No constants in Constants::PT is 1337')
      expect { @elf.segment_by_type(:xx) }.to raise_error(ArgumentError, 'No constants in Constants::PT named "PT_XX"')
    end
  end

  describe 'offset_from_vma' do
    it 'converts' do
      expect(@elf.offset_from_vma(0x400042)).to eq(0x42)
    end

    it 'when invalid address' do
      expect(@elf.offset_from_vma(0)).to eq(nil)
    end
  end

  describe 'vma_from_offset' do
    it 'converts' do
      expect(@elf.vma_from_offset(0x42)).to eq(0x400042)
    end

    it 'when invalid address' do
      expect(@elf.vma_from_offset(0x12345678)).to eq(nil)
    end
  end

  describe 'dynamic' do
    def elf(name)
      described_class.new(File.open(File.join(__dir__, 'files', name)))
    end

    # Returns an ELF file whose header has been modified by +block+.
    # @yieldparam [ELFTools::Structs::ELF_Ehdr] header The ELF header.
    # @yieldreturn [void]
    # @return [ELFTools::ELFFile]
    def elf_with_patched_header(name)
      data = File.binread(File.join(__dir__, 'files', name))
      header = described_class.new(StringIO.new(data)).header
      yield header
      data[0, header.num_bytes] = header.to_binary_s
      described_class.new(StringIO.new(data))
    end

    it 'reads the tags a loaded file is loaded by' do
      # An executable and a shared object record the same tags twice, and the
      # segment is the one the kernel and the loader read.
      %w[amd64.elf libc.so.6].each do |name|
        file = elf(name)
        expect(file.dynamic).to be_a ELFTools::Segments::DynamicSegment
        expect(file.dynamic.tags.size).to eq file.section_by_name('.dynamic').tags.size
      end
    end

    it 'reads none from a file that records none' do
      # A relocatable file is linked by its sections and has no segments.
      expect(elf('mips64.o').segments).to be_empty
      expect(elf('mips64.o').dynamic).to be nil
    end

    it 'disregards the segments of a file that says it is relocatable' do
      # Segments on an object file are something no linker reads, forged or
      # left over, and the sections are what governs it either way.
      file = elf_with_patched_header('amd64.elf') { |header| header.e_type = ELFTools::Constants::ET_REL }
      expect(file.segment_by_type(:dynamic)).not_to be nil
      expect(file.dynamic).to be_a ELFTools::Sections::DynamicSection
    end

    it 'falls back to the section of a file that has no segments' do
      file = elf_with_patched_header('amd64.elf') { |header| header.e_phnum = 0 }
      expect(file.segments).to be_empty
      expect(file.dynamic).to be_a ELFTools::Sections::DynamicSection
      expect(file.dynamic.tags.size).to eq elf('amd64.elf').dynamic.tags.size
      # A tag names a string by address, which only the segments resolve.
      expect { file.dynamic.tag_by_type(:needed).name }.to raise_error ELFTools::ELFError
    end
  end

  describe 'a file too large for the counts the ELF header records' do
    # A real file with 65280 sections is enormous, so this is amd64.elf with
    # its counts moved to where such a file states them.
    def extended
      data = File.binread(@filepath)
      elf = described_class.new(StringIO.new(data))
      counts = [elf.num_sections, elf.header.e_shstrndx.to_i, elf.num_segments]
      zero = elf.section_at(0).header
      zero.sh_size, zero.sh_link, zero.sh_info = counts
      elf.header.e_shnum = 0
      elf.header.e_shstrndx = ELFTools::Constants::SHN_XINDEX
      elf.header.e_phnum = ELFTools::Constants::PN_XNUM
      data[0, elf.header.num_bytes] = elf.header.to_binary_s
      data[elf.header.e_shoff.to_i, zero.num_bytes] = zero.to_binary_s
      [described_class.new(StringIO.new(data)), counts]
    end

    it 'counts what the first section header states' do
      elf, counts = extended
      expect([elf.num_sections, elf.num_segments]).to eq [counts[0], counts[2]]
      expect(elf.sections.size).to be counts[0]
      expect(elf.segments.size).to be counts[2]
    end

    it 'names its sections through the index the first section header states' do
      elf, = extended
      expect(elf.section_name_table.name).to eq '.shstrtab'
      expect(elf.section_by_name('.text')).not_to be nil
      expect(elf.sections.map(&:name)).to include '.dynsym', '.shstrtab'
    end

    it 'counts no sections where a file records no section headers' do
      # The same zero, of a file that has none rather than too many.
      data = File.binread(@filepath)
      header = described_class.new(StringIO.new(data)).header
      header.e_shoff = 0
      header.e_shnum = 0
      data[0, header.num_bytes] = header.to_binary_s
      expect(described_class.new(StringIO.new(data)).num_sections).to be 0
    end
  end

  describe 'patches' do
    it 'dup' do
      out = Tempfile.new('elftools')
      out.close
      @elf.save(out.path)
      out.reopen(out.path, 'rb')
      expect(out.read.force_encoding('ascii-8bit')).to eq File.binread(@filepath)
      out.close!
    end

    it 'reports what a tag and a symbol read through the tags were assigned' do
      # Both are remembered in a hash rather than an array, which used to keep
      # them out of the answer and out of what was written.
      elf = described_class.new(File.open(@filepath))
      tag = elf.dynamic.tag_by_type(:strtab)
      tag.header.d_val = 0x4142
      elf.dynamic.symbol_at(1).type = ELFTools::Constants::STT_OBJECT
      expect(elf.patches.size).to be 2

      out = Tempfile.new('elftools')
      out.close
      elf.save(out.path)
      out.reopen(out.path, 'rb')
      saved = described_class.new(out)
      expect(saved.dynamic.tag_by_type(:strtab).header.d_val.to_i).to be 0x4142
      expect(saved.dynamic.symbol_at(1).type).to be ELFTools::Constants::STT_OBJECT
      out.close!
    end

    it 'patch header' do
      out = Tempfile.new('elftools')
      out.close
      # prevent affect other tests
      elf = described_class.new(File.open(@filepath))
      expect(elf.machine).to eq 'Advanced Micro Devices X86-64 processor'
      expect(elf.section_by_name('.text').header.sh_addr).to eq 0x4005b0
      elf.header.e_machine = 40
      elf.section_by_name('.text').header.sh_addr = 0xdeadbeef
      expect(elf.machine).to eq 'ARM'
      elf.save(out.path)
      out.reopen(out.path, 'rb')
      patched_elf = described_class.new(out)
      expect(patched_elf.machine).to eq 'ARM'
      expect(patched_elf.section_by_name('.text').header.sh_addr).to eq 0xdeadbeef
      out.close!
    end

    it 'patches a field of a structure a header records' do
      out = Tempfile.new('elftools')
      out.close
      elf = described_class.new(File.open(@filepath))
      elf.header.e_ident.ei_abiversion = 41
      elf.save(out.path)
      out.reopen(out.path, 'rb')
      expect(described_class.new(out).header.e_ident.ei_abiversion).to eq 41
      out.close!
    end

    it 'strips the section headers off a file of any width and order' do
      # The fields recording where the sections are take a different width in
      # each ELF class and are written in a different order by each file, and a
      # file whose header is written wrongly no longer reads as an ELF at all.
      { 'amd64.elf' => 0x28, 'i386.elf' => 0x20, 'ppc64.elf' => 0x28 }.each do |name, shoff_at|
        path = File.join(__dir__, 'files', name)
        elf = described_class.new(File.open(path))
        width = elf.elf_class / 8
        # e_flags, e_ehsize, e_phentsize, e_phnum, and e_shentsize sit between
        # e_shoff and the two fields that follow it, e_shnum and e_shstrndx.
        shnum_at = shoff_at + width + 4 + 2 + 2 + 2 + 2
        elf.header.e_shoff = 0
        elf.header.e_shnum = 0
        elf.header.e_shstrndx = 0

        out = Tempfile.new('elftools')
        out.close
        elf.save(out.path)
        before = File.binread(path)
        after = File.binread(out.path)

        # Nothing outside the three fields moved, so what the segments record
        # is left where it was.
        expect(after.bytesize).to eq before.bytesize
        untouched = (0...before.bytesize).reject do |i|
          i.between?(shoff_at, shoff_at + width - 1) || i.between?(shnum_at, shnum_at + 3)
        end
        expect(untouched.all? { |i| after.getbyte(i) == before.getbyte(i) }).to be true

        stripped = described_class.new(File.open(out.path))
        expect(stripped.header.e_shoff).to eq 0
        expect(stripped.header.e_shnum).to eq 0
        expect(stripped.header.e_shstrndx).to eq 0
        expect(stripped.sections).to eq []
        # The symbols the tags point at are what a stripped file still records.
        expect(stripped.segment_by_type(:dynamic).symbols.map(&:name))
          .to eq described_class.new(File.open(path)).segment_by_type(:dynamic).symbols.map(&:name)
        out.close!
      end
    end

    it 'patches a field of every width the way the file orders it' do
      # A value whose bytes all differ reads back only if every one of them is
      # written where the file expects it.
      { 'amd64.elf' => 0x1122334455667788, 'i386.elf' => 0x11223344, 'ppc64.elf' => 0x1122334455667788 }
        .each do |name, value|
        out = Tempfile.new('elftools')
        out.close
        elf = described_class.new(File.open(File.join(__dir__, 'files', name)))
        elf.header.e_shoff = value
        elf.save(out.path)
        expect(described_class.new(File.open(out.path)).header.e_shoff).to eq value
        out.close!
      end
    end

    it 'patches a file whichever way it is ordered' do
      # A field is written the way the file records it, which only a big
      # endian file disagrees with.
      %w[amd64.elf ppc64.elf].each do |name|
        out = Tempfile.new('elftools')
        out.close
        elf = described_class.new(File.open(File.join(__dir__, 'files', name)))
        elf.header.e_machine = ELFTools::Constants::EM_ARM
        elf.save(out.path)
        out.reopen(out.path, 'rb')
        expect(described_class.new(out).machine).to eq 'ARM'
        out.close!
      end
    end
  end

  describe 'accessibility' do
    it 'allows headers to_h' do
      dyn = @elf.sections_by_type(:dynamic).first.tag_at(0)
      expect(dyn.header.to_h.keys).to eq %i[d_tag d_val]
      expect(dyn.header.to_h.values).to eq [1, 1]
    end
  end
end
