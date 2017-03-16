require 'elftools'

describe 'Full test for shared object' do
  before(:all) do
    path = File.join(__dir__, '..', 'files', 'i386.so.elf')
    @elf = ELFTools::ELFFile.new(File.open(path))
    filepath = File.join(__dir__, '..', 'files', 'libc.so.6')
    @libc = ELFTools::ELFFile.new(File.open(filepath))
  end

  it 'elf_file' do
    expect(@elf.endian).to be :little
    expect(@elf.elf_class).to be 32
    expect(@elf.build_id).to eq '09990651ce15ffd2c03e0bd4eda54ab5b4cadbd9'
    expect(@elf.elf_type).to eq 'DYN'
  end

  it 'sections' do
    expect(@elf.sections.size).to be 29
    expect(@elf.section_by_name('.dynsym').symbols.size).to eq 20
    expect(@elf.section_by_name('.symtab').symbols.size).to eq 68
    expect(@elf.section_by_name('.symtab').symbol_by_name('puts@@GLIBC_2.0')).to be_a ELFTools::Sections::Symbol
  end

  it 'segments' do
    expect(@elf.segments.size).to be 7
    expect(@elf.segment_by_type(:interp)).to be nil # shared object no need interpreter
    expect(@elf.segment_by_type(:note).notes.size).to be 1 # only build id remained
    expect(@elf.segment_by_type(:gnu_stack).executable?).to be false
    expect(@libc.segment_by_type(:dynamic).tag_by_type(:soname).value).to eq 'libc.so.6'
    expect(@libc.segment_by_type(:dynamic).tag_by_type(:needed).value).to eq 'ld-linux-x86-64.so.2'
  end
end
