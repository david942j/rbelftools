# frozen_string_literal: true

require 'elftools'

describe 'Full test for riscv64' do
  before(:all) do
    path = File.join(__dir__, '..', 'files', 'riscv64.elf')
    @elf = ELFTools::ELFFile.new(File.open(path))
  end

  it 'elf_file' do
    expect(@elf.endian).to be :little
    expect(@elf.elf_class).to be 64
    expect(@elf.build_id).to eq 'c352d488d3467ababc488ab28758e968d84f8db8'
    expect(@elf.machine).to eq 'RISC-V'
    expect(@elf.elf_type).to eq 'DYN'
  end

  it 'sections' do
    expect(@elf.sections.size).to be 28
    expect(@elf.section_by_name('.dynsym').symbols.size).to eq 8
    expect(@elf.section_by_name('.symtab').symbols.size).to eq 66
    expect(@elf.section_by_name('.symtab').symbol_by_name('puts@GLIBC_2.27')).to be_a ELFTools::Sections::Symbol
  end

  it 'segments' do
    expect(@elf.segments.size).to be 10
    expect(@elf.segment_by_type(:interp).interp_name).to eq '/lib/ld-linux-riscv64-lp64d.so.1'
    expect(@elf.segment_by_type(:note).notes.size).to be 2
    expect(@elf.segment_by_type(:gnu_stack).executable?).to be false
    expect(@elf.segment_by_type(:load).offset_in?(0x12345678)).to be false
    expect(@elf.segment_by_type(:load).offset_to_vma(0)).to be 0
  end
end
