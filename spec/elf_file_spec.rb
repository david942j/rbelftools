# encoding: ascii-8bit
require 'elftools/elf_file'
describe ELFTools::ELFFile do
  before(:all) do
    filepath = File.join(__dir__, 'files', 'amd64')
    @elf = ELFTools::ELFFile.new(File.open(filepath))
  end

  it 'basic' do
    expect(@elf.elf_class).to be 64
    expect(@elf.endian).to be :little
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
      expect(@elf.sections.map(&:name)).to eq [''] + %w(
        .interp .note.ABI-tag .note.gnu.build-id .gnu.hash
        .dynsym .dynstr .gnu.version .gnu.version_r
        .rela.dyn .rela.plt .init .plt .plt.got .text
        .fini .rodata .eh_frame_hdr .eh_frame .init_array
        .fini_array .jcr .dynamic .got .got.plt .data .bss
        .comment .shstrtab .symtab .strtab
      )

      expect(@elf.section_by_name('.shstrtab')).to be @elf.strtab_section
      expect(@elf.section_by_name('no such section')).to be nil
    end

    it 'data' do
      expect(@elf.section_by_name('.note.gnu.build-id').data)
        .to eq "\x04\x00\x00\x00\x14\x00\x00\x00\x03\x00\x00\x00"\
               "GNU\x00s\xABb\xCB{\xC9\x95\x9C\xE0S\xC2\xB7\x112!Xp\x8C\xDC\a"
    end

    it 'symbols' do
      # symbols from .dynsym
      section = @elf.section_by_name('.dynsym')
      expect(section.symbols.map(&:name)).to eq [''] + %w(
        puts __stack_chk_fail printf __libc_start_main
        fgets __gmon_start__ scanf stdin
      )

      # symbols from .symtab
      section = @elf.section_by_name('.symtab')
      # Too many symbols, only test non-empty names
      expect(section.symbols.map(&:name).reject(&:empty?)).to eq %w(
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
      )

      # can use 'be' here becauase they should always refer to same object
      expect(section.symbol_by_name('_init')).to be section.symbols.last
    end

    it 'notes' do
      secs = @elf.sections.select { |sec| sec.instance_of?(ELFTools::NoteSection) }
      # There're two note sections
      expect(secs.size).to be 2
      bid_sec = secs.last
      expect(bid_sec.notes[0].name).to eq "GNU\x00"
      # The build id
      expect(bid_sec.notes[0].desc.unpack('H*')[0]).to eq '73ab62cb7bc9959ce053c2b711322158708cdc07'
    end
  end

  describe 'segments' do
    it 'basic' do
      expect(@elf.num_segments).to eq 9
      expect(@elf.segments[1]).to be @elf.segment_at(1)
      expect(@elf.segment_by_type(:note).readable?).to be true
      expect(@elf.segment_by_type(:phdr).executable?).to be true
      expect(@elf.segment_by_type(:gnu_stack).executable?).to be false
      expect(@elf.segment_by_type(:gnu_stack).writable?).to be true
    end

    it 'data' do
      expect(@elf.segment_at(1).data).to eq "/lib64/ld-linux-x86-64.so.2\x00"
    end

    it 'interp' do
      expect(@elf.segment_at(1)).to be_a ELFTools::InterpSegment
      expect(@elf.segment_at(1).interp_name).to eq '/lib64/ld-linux-x86-64.so.2'
    end

    it 'notes' do
      seg = @elf.segment_by_type(ELFTools::Constants::PT_NOTE)
      expect(seg.notes[1].name).to eq "GNU\x00"
      # The build id
      expect(seg.notes[1].desc.unpack('H*')[0]).to eq '73ab62cb7bc9959ce053c2b711322158708cdc07'
    end

    it 'segment_by_type' do
      expect(@elf.segment_by_type(ELFTools::Constants::PT_NOTE)).to be_a ELFTools::NoteSegment
      expect(@elf.segment_by_type(4)).to be_a ELFTools::NoteSegment
      expect(@elf.segment_by_type(:note)).to be_a ELFTools::NoteSegment
      expect(@elf.segment_by_type('note')).to be_a ELFTools::NoteSegment
      expect(@elf.segment_by_type('NoTe')).to be_a ELFTools::NoteSegment
      expect(@elf.segment_by_type('PT_NOTE')).to be_a ELFTools::NoteSegment
      expect(@elf.segment_by_type(:PT_NOTE)).to be_a ELFTools::NoteSegment
      expect { @elf.segment_by_type(1337) }.to raise_error(ArgumentError, 'No PT type is "1337"')
      expect { @elf.segment_by_type(:oao) }.to raise_error(ArgumentError, 'No PT type named "PT_OAO"')
    end
  end
end
