# frozen_string_literal: true

require 'elftools/elf_file'

describe ELFTools::RelativeRelocations do
  def elf(name = 'aarch64.relr.elf')
    ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name)))
  end

  def section(file)
    file.sections.find { |sec| sec.is_a?(ELFTools::Sections::RelativeRelocationSection) }
  end

  it 'unpacks what a bitmap holds' do
    # 6 entries of 8 bytes hold 132 relocations, which as many RELA entries
    # would have taken 3168.
    packed = section(elf)
    expect(packed.header.sh_size.to_i).to eq 48
    expect(packed.num_relocations).to eq 132
  end

  it 'reads the addresses in the ascending order they are recorded in' do
    offsets = section(elf).relocations.map { |rel| rel.header.r_offset.to_i }
    expect(offsets).to eq offsets.sort
    expect(offsets.uniq.size).to eq offsets.size
  end

  it 'reports what the format implies rather than what it records' do
    # Nothing is recorded but an address, so the type is the one the machine
    # calls relative, there is no symbol, and the addend is what is already
    # in place rather than a number of its own.
    rel = section(elf).relocations.first
    expect(rel.type_name).to eq 'R_AARCH64_RELATIVE'
    expect(rel.symbol_index).to be 0
    expect(rel.header.r_addend).to be nil
  end

  it 'is read the same from the tags as from the sections' do
    file = elf
    from_tags = file.dynamic.relocations.map { |rel| rel.header.r_offset.to_i }
    expect(from_tags).to include(*section(file).relocations.map { |rel| rel.header.r_offset.to_i })
  end

  it 'reads them from a file that has no sections left' do
    data = File.binread(File.join(__dir__, 'files', 'aarch64.relr.elf'))
    header = ELFTools::ELFFile.new(StringIO.new(data)).header
    header.e_shoff = 0
    header.e_shnum = 0
    header.e_shstrndx = 0
    data[0, header.num_bytes] = header.to_binary_s
    file = ELFTools::ELFFile.new(StringIO.new(data))
    expect(file.sections).to be_empty
    expect(file.dynamic.relocations.size).to eq elf.dynamic.relocations.size
  end

  it 'reads nothing from a file recording no such table' do
    file = elf('amd64.elf')
    expect(file.dynamic.tag_by_type(:relr)).to be nil
    expect(section(file)).to be nil
    expect(file.dynamic.relocations).not_to be_empty
  end
end
