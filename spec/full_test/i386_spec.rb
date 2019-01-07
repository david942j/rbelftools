require 'elftools'

describe 'Full test for i386' do
  before(:all) do
    path = File.join(__dir__, '..', 'files', 'i386.elf')
    @elf = ELFTools::ELFFile.new(File.open(path))
  end

  it 'elf_file' do
    expect(@elf.endian).to be :little
    expect(@elf.elf_class).to be 32
    expect(@elf.build_id).to eq '5aea20bbb3584e68603209eb2a90b718750e1f29'
    expect(@elf.machine).to eq 'Intel 80386'
    expect(@elf.elf_type).to eq 'EXEC'
  end

  it 'sections' do
    expect(@elf.sections.size).to be 31
    expect(@elf.section_by_name('.dynsym').symbols.size).to eq 10
    expect(@elf.section_by_name('.symtab').symbols.size).to eq 77
    expect(@elf.section_by_name('.symtab').symbol_by_name('puts@@GLIBC_2.0')).to be_a ELFTools::Sections::Symbol
  end

  it 'segments' do
    expect(@elf.segments.size).to be 9
    expect(@elf.segment_by_type(:interp).interp_name).to eq '/lib/ld-linux.so.2'
    expect(@elf.segment_by_type(:note).notes.size).to be 2
    expect(@elf.segment_by_type(:gnu_stack).executable?).to be false
    expect(@elf.segment_by_type(:load).offset_in?(0x12345678)).to be false
    expect(@elf.segment_by_type(:load).offset_to_vma(0)).to be 0x8048000
  end
end
