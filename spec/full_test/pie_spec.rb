require 'elftools'

describe 'Full test for PIE' do
  before(:all) do
    path = File.join(__dir__, '..', 'files', 'i386.pie.elf')
    @elf = ELFTools::ELFFile.new(File.open(path))
  end

  it 'elf_file' do
    expect(@elf.endian).to be :little
    expect(@elf.elf_class).to be 32
  end

  it 'sections' do
    expect(@elf.sections.size).to be 29
    build_id = @elf.section_by_name('.note.gnu.build-id').notes[0].desc.unpack('H*')[0]
    expect(build_id).to eq '09990651ce15ffd2c03e0bd4eda54ab5b4cadbd9'
    expect(@elf.section_by_name('.dynsym').symbols.size).to eq 20
    expect(@elf.section_by_name('.symtab').symbols.size).to eq 68
    expect(@elf.section_by_name('.symtab').symbol_by_name('puts@@GLIBC_2.0')).to be_a ELFTools::Sections::Symbol
  end

  it 'segments' do
    expect(@elf.segments.size).to be 7
    expect(@elf.segment_by_type(:interp)).to be nil # Well.. why no interpreter in a PIE binary?
    expect(@elf.segment_by_type(:note).notes.size).to be 1 # only build id remained
    expect(@elf.segment_by_type(:gnu_stack).executable?).to be false
  end
end