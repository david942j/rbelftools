# frozen_string_literal: true

require 'elftools/constants'
require 'elftools/elf_file'

describe ELFTools::Sections::Symbol do
  before(:all) do
    filepath = File.join(__dir__, 'files', 'amd64.elf')
    @symtab = ELFTools::ELFFile.new(File.open(filepath)).section_by_name('.symtab')
  end

  it 'type' do
    expect(@symtab.symbol_by_name('main').type).to be ELFTools::Constants::STT_FUNC
    expect(@symtab.symbol_by_name('__JCR_LIST__').type).to be ELFTools::Constants::STT_OBJECT
    expect(@symtab.symbol_by_name('crtstuff.c').type).to be ELFTools::Constants::STT_FILE
  end

  it 'bind' do
    expect(@symtab.symbol_by_name('main').bind).to be ELFTools::Constants::STB_GLOBAL
    expect(@symtab.symbol_by_name('crtstuff.c').bind).to be ELFTools::Constants::STB_LOCAL
    expect(@symtab.symbol_by_name('__gmon_start__').bind).to be ELFTools::Constants::STB_WEAK
  end

  it 'visibility' do
    expect(@symtab.symbol_by_name('main').visibility).to be ELFTools::Constants::STV_DEFAULT
    expect(@symtab.symbol_by_name('__dso_handle').visibility).to be ELFTools::Constants::STV_HIDDEN
  end

  it 'names what it decodes' do
    main = @symtab.symbol_by_name('main')
    expect([main.type_name, main.bind_name, main.visibility_name]).to eq %w[STT_FUNC STB_GLOBAL STV_DEFAULT]
    expect(@symtab.symbol_by_name('crtstuff.c').type_name).to eq 'STT_FILE'
    expect(@symtab.symbol_by_name('__gmon_start__').bind_name).to eq 'STB_WEAK'
    expect(@symtab.symbol_by_name('__dso_handle').visibility_name).to eq 'STV_HIDDEN'
  end

  it 'names a type only the OS defining it records' do
    filepath = File.join(__dir__, 'files', 'libc.so.6')
    dynsym = ELFTools::ELFFile.new(File.open(filepath)).section_by_name('.dynsym')
    ifunc = dynsym.symbols.find { |symbol| symbol.type == ELFTools::Constants::STT_GNU_IFUNC }
    # The value is STT_LOOS as well, which only marks where a range begins.
    expect(ifunc.type_name).to eq 'STT_GNU_IFUNC'
  end

  it 'section_index' do
    # Symbols to be resolved at runtime are not defined in any section.
    expect(@symtab.symbol_by_name('puts@@GLIBC_2.2.5').section_index).to be ELFTools::Constants::SHN_UNDEF
    expect(@symtab.symbol_by_name('main').section_index).to be 14
  end

  it 'works on 32-bit' do
    filepath = File.join(__dir__, 'files', 'i386.elf')
    symtab = ELFTools::ELFFile.new(File.open(filepath)).section_by_name('.symtab')
    main = symtab.symbol_by_name('main')
    expect(main.type).to be ELFTools::Constants::STT_FUNC
    expect(main.bind).to be ELFTools::Constants::STB_GLOBAL
    expect(main.visibility).to be ELFTools::Constants::STV_DEFAULT
  end
end
