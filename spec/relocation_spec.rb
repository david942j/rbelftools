# frozen_string_literal: true

require 'elftools/elf_file'

describe ELFTools::Relocation do
  def relocations(name)
    elf = ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name)))
    (elf.sections_by_type(:rel) + elf.sections_by_type(:rela)).flat_map(&:relocations)
  end

  # A REL relocation records no addend, the content it relocates carries one
  # instead, so both kinds answer for an addend and only one answers with a
  # number.
  it 'reads either kind of relocation' do
    rel = relocations('i386.elf')
    expect(rel).not_to be_empty
    expect(rel.map { |r| r.header.r_addend }).to all(be_nil)

    addends = relocations('aarch64.elf').map { |r| r.header.r_addend&.to_i }
    expect(addends).to all(be_an(Integer))
    expect(addends).to include(be_positive)
  end
end
