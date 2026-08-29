# frozen_string_literal: true

require 'elftools/constants'
require 'tempfile'

require 'elftools/elf_file'

describe ELFTools::Sections::Symbol do
  before(:all) do
    filepath = File.join(__dir__, 'files', 'amd64.elf')
    @symtab = ELFTools::ELFFile.new(File.open(filepath)).section_by_name('.symtab')
  end

  def own_symtab(name = 'amd64.elf')
    ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name))).section_by_name('.symtab')
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
  # Writing back what was read changes neither the byte a type and a binding
  # share nor the one a visibility shares with whatever else a machine puts
  # there.
  it 'writes each value back where it was read from' do
    symtab = own_symtab
    expect(symtab.symbols).not_to be_empty
    symtab.symbols.each do |sym|
      info = sym.header.st_info.to_i
      other = sym.header.st_other.to_i
      wanted = [sym.type, sym.bind, sym.visibility]
      sym.type = wanted[0]
      sym.bind = wanted[1]
      sym.visibility = wanted[2]
      expect([sym.header.st_info.to_i, sym.header.st_other.to_i]).to eq [info, other]
      expect([sym.type, sym.bind, sym.visibility]).to eq wanted
    end
  end

  it 'leaves what a visibility shares its byte with alone' do
    sym = own_symtab.symbol_by_name('main')
    sym.header.st_other = 0xfd # something of a machine's own, and STV_INTERNAL
    sym.visibility = ELFTools::Constants::STV_HIDDEN
    expect(sym.header.st_other.to_i).to eq 0xfe
    expect(sym.visibility).to be ELFTools::Constants::STV_HIDDEN
  end

  it 'reports a value the bits recording it cannot hold' do
    sym = own_symtab.symbol_by_name('main')
    expect { sym.type = 16 }.to raise_error(ArgumentError, 'Symbol type must be in 0..15, got 16')
    expect { sym.bind = 16 }.to raise_error(ArgumentError, 'Symbol binding must be in 0..15, got 16')
    expect { sym.visibility = 4 }.to raise_error(ArgumentError, 'Symbol visibility must be in 0..3, got 4')
  end

  it 'survives being written out' do
    out = Tempfile.new('elftools')
    out.close
    elf = ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', 'amd64.elf')))
    sym = elf.section_by_name('.symtab').symbol_by_name('main')
    sym.type = ELFTools::Constants::STT_OBJECT
    sym.bind = ELFTools::Constants::STB_WEAK
    sym.visibility = ELFTools::Constants::STV_HIDDEN
    elf.save(out.path)
    out.reopen(out.path, 'rb')
    saved = ELFTools::ELFFile.new(out).section_by_name('.symtab').symbol_by_name('main')
    expect([saved.type_name, saved.bind_name, saved.visibility_name])
      .to eq %w[STT_OBJECT STB_WEAK STV_HIDDEN]
    out.close!
  end
  it 'value' do
    # What a symbol of a file that is loaded is worth is the address of what
    # it names.
    expect(@symtab.symbol_by_name('main').value).to be 0x4006dd
    expect(@symtab.symbol_by_name('main').value).to eq @symtab.symbol_by_name('main').header.st_value
    # A file that is not loaded anywhere records an offset into the section
    # holding it instead.
    relocatable = ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', 'mips.o')))
    helper = relocatable.section_by_name('.symtab').symbol_by_name('_ZL6helperi')
    expect(helper.value).to be 132
    expect(helper.section_index).to be 2
  end

  it 'size' do
    expect(@symtab.symbol_by_name('main').size).to be 142
    # A symbol the file records no size for, of which every file has some.
    expect(@symtab.symbol_by_name('crtstuff.c').size).to be 0
  end
end
