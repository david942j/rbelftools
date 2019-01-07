require 'elftools'

describe 'Full test for PIE' do
  before(:all) do
    path = File.join(__dir__, '..', 'files', 'i386.pie.elf')
    @elf = ELFTools::ELFFile.new(File.open(path))
  end

  it 'elf_file' do
    expect(@elf.endian).to be :little
    expect(@elf.elf_class).to be 32
    expect(@elf.build_id).to eq '6842bbffe6e6b684b19d59ec5774b9a51df0230e'
  end

  it 'sections' do
    expect(@elf.sections.size).to be 31
    expect(@elf.section_by_name('.dynsym').symbols.size).to eq 18
    expect(@elf.section_by_name('.symtab').symbols.size).to eq 79
    expect(@elf.section_by_name('.symtab').symbol_by_name('puts@@GLIBC_2.0')).to be_a ELFTools::Sections::Symbol
  end

  it 'segments' do
    expect(@elf.segments.size).to be 9
    expect(@elf.segment_by_type(:interp).interp_name).to eq '/lib/ld-linux.so.2'
    expect(@elf.segment_by_type(:note).notes.size).to be 2
    expect(@elf.segment_by_type(:gnu_stack).executable?).to be false
    expect(@elf.segment_by_type(:load).offset_in?(0x12345678)).to be false
    expect(@elf.segment_by_type(:load).offset_to_vma(0x33)).to be 0x33
  end
end
