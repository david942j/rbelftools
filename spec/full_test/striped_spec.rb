require 'elftools'

describe 'Full test for striped binary' do
  before(:all) do
    path = File.join(__dir__, '..', 'files', 'amd64.strip.elf')
    @elf = ELFTools::ELFFile.new(File.open(path))
  end

  it 'elf_file' do
    expect(@elf.endian).to be :little
    expect(@elf.elf_class).to be 64
    expect(@elf.build_id).to eq '73ab62cb7bc9959ce053c2b711322158708cdc07'
  end

  it 'sections' do
    expect(@elf.sections.size).to be 29
    expect(@elf.section_by_name('.dynsym').symbols.size).to eq 9
    expect(@elf.section_by_name('.symtab')).to be nil # striped!
  end

  it 'segments' do
    expect(@elf.segments.size).to be 9
    expect(@elf.segment_by_type(:interp).interp_name).to eq '/lib64/ld-linux-x86-64.so.2'
    expect(@elf.segment_by_type(:note).notes.size).to be 2
    expect(@elf.segment_by_type(:gnu_stack).executable?).to be false
  end
end
