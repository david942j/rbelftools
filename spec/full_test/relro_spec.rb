# frozen_string_literal: true

require 'elftools'

describe 'Full test for relro types' do
  before(:all) do
    path = File.join(__dir__, '..', 'files', 'amd64.nrelro.elf')
    @nrelro = ELFTools::ELFFile.new(File.open(path))
    path = File.join(__dir__, '..', 'files', 'amd64.elf')
    @partial = ELFTools::ELFFile.new(File.open(path))
    path = File.join(__dir__, '..', 'files', 'amd64.frelro.elf')
    @frelro = ELFTools::ELFFile.new(File.open(path))
  end

  it 'section size' do
    expect(@nrelro.sections_by_type(:rela).size).to be 2
    expect(@partial.sections_by_type(:rela).size).to be 2
    expect(@frelro.sections_by_type(:rela).size).to be 1
  end

  it '.rela.dyn' do
    expect(@nrelro.section_by_name('.rela.dyn').relocations.size).to be 2
    expect(@frelro.section_by_name('.rela.dyn').relocations.size).to be 8
  end

  it '.rela.plt' do
    expect(@nrelro.section_by_name('.rela.plt').relocations.size).to be 6
    expect(@partial.section_by_name('.rela.plt').relocations.size).to be 6
    expect(@frelro.section_by_name('.rela.plt')).to be nil
  end

  it 'r_info type' do
    expect(@nrelro.section_by_name('.rela.plt').relocations.map(&:r_info_type).uniq).to eq [7]
    expect(@partial.section_by_name('.rela.plt').relocations.map(&:r_info_type).uniq).to eq [7]

    expect(@partial.section_by_name('.rela.dyn').relocations.map(&:r_info_type)).to eq [6, 5]
    expect(@frelro.section_by_name('.rela.dyn').relocations.map(&:r_info_type)).to eq [6, 6, 6, 6, 6, 6, 6, 5]
  end

  it 'plt symbols' do
    section = @partial.section_by_name('.rela.plt')
    symtab = @partial.section_at(section.header.sh_link)
    symbols = section.relocations.map(&:r_info_sym).map { |c| symtab.symbol_at(c).name }
    expect(symbols).to eq %w[puts __stack_chk_fail printf __libc_start_main fgets scanf]

    section = @nrelro.section_by_name('.rela.plt')
    symtab = @nrelro.section_at(section.header.sh_link)
    nrelro_symbols = section.relocations.map(&:r_info_sym).map { |c| symtab.symbol_at(c).name }
    expect(nrelro_symbols).to eq symbols
  end

  it 'dyn symbols' do
    section = @partial.section_by_name('.rela.dyn')
    symtab = @partial.section_at(section.header.sh_link)
    symbols = section.relocations.map(&:r_info_sym).map { |c| symtab.symbol_at(c).name }
    expect(symbols).to eq %w[__gmon_start__ stdin]

    section = @frelro.section_by_name('.rela.dyn')
    symtab = @frelro.section_at(section.header.sh_link)
    frelro_symbols = section.relocations.map(&:r_info_sym).map { |c| symtab.symbol_at(c).name }
    expect(frelro_symbols).to eq %w[puts __stack_chk_fail printf __libc_start_main fgets __gmon_start__ scanf stdin]
  end
end
