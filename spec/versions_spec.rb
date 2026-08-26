# frozen_string_literal: true

require 'stringio'

require 'elftools/elf_file'

describe ELFTools::Dynamic::Versions do
  def dynamic(name = 'amd64.elf')
    ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name))).dynamic
  end

  # Returns a file whose tag of +type+ no longer exists.
  def elf_without_tag(name, type)
    data = File.binread(File.join(__dir__, 'files', name))
    header = ELFTools::ELFFile.new(StringIO.new(data)).dynamic.tag_by_type(type).header
    header.d_tag = ELFTools::Constants::DT_DEBUG
    data[header.offset, header.num_bytes] = header.to_binary_s
    ELFTools::ELFFile.new(StringIO.new(data))
  end

  describe 'version_requirements' do
    it 'reads what a file needs of the files it is loaded with' do
      needs = dynamic.version_requirements
      expect(needs.size).to be 1
      expect(needs.first.file).to eq 'libc.so.6'
      expect(needs.first.versions.map(&:name)).to eq %w[GLIBC_2.4 GLIBC_2.2.5]
      # The index is what a symbol names the version with.
      expect(needs.first.versions.map(&:index)).to eq [3, 2]
    end

    it 'reads what a library needs of the loader' do
      needs = dynamic('libc.so.6').version_requirements
      expect(needs.map(&:file)).to eq ['ld-linux-x86-64.so.2']
      expect(needs.first.versions.map(&:name)).to eq %w[GLIBC_2.3 GLIBC_PRIVATE]
    end

    it 'reads nothing from a file recording none' do
      expect(elf_without_tag('amd64.elf', :verneed).dynamic.version_requirements).to eq []
    end
  end

  describe 'version_definitions' do
    it 'reads what a library defines' do
      definitions = dynamic('libc.so.6').version_definitions
      expect(definitions.size).to be 25
      # The first names the file rather than a version of it.
      expect(definitions.first.name).to eq 'libc.so.6'
      expect(definitions.first).to be_base
      expect(definitions.first.index).to be 1
      expect(definitions.first.parents).to eq []
      # The rest descend from the one before, as glibc versions do.
      expect(definitions[1].name).to eq 'GLIBC_2.2.5'
      expect(definitions[1]).not_to be_base
      expect(definitions[2].name).to eq 'GLIBC_2.2.6'
      expect(definitions[2].parents).to eq ['GLIBC_2.2.5']
    end

    it 'reads nothing from a file defining none' do
      # An executable exports nothing under a version of its own.
      expect(dynamic.version_definitions).to eq []
    end
  end

  describe 'the version a symbol binds to' do
    it 'names it' do
      symbols = dynamic.symbols
      expect(symbols.map(&:version)).to eq [nil, 'GLIBC_2.2.5', 'GLIBC_2.4', 'GLIBC_2.2.5', 'GLIBC_2.2.5',
                                            'GLIBC_2.2.5', nil, 'GLIBC_2.2.5', 'GLIBC_2.2.5']
      # The name is left as the file records it.
      expect(symbols[1].name).to eq 'puts'
    end

    it 'tells a version asked for by name from the default one' do
      # More than one version of a name is what makes the others hidden, and
      # only a library defining versions has them.
      hidden = dynamic('libc.so.6').symbols.select(&:version_hidden?)
      expect(hidden.size).to be 51
      expect(hidden.map(&:name)).to include 'pthread_cond_signal'
      expect(dynamic.symbols.map(&:version_hidden?)).to all(be false)
    end

    it 'names none where the file records none' do
      file = elf_without_tag('amd64.elf', :versym)
      expect(file.dynamic.symbols.map(&:version)).to all(be nil)
      expect(file.dynamic.symbols.map(&:version_hidden?)).to all(be false)
    end

    it 'names none for a symbol read from a section' do
      # A symbol table that is not the one a file is loaded by has no versions.
      elf = ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', 'amd64.elf')))
      symbol = elf.section_by_name('.symtab').symbol_by_name('main')
      expect(symbol.version).to be nil
      expect(symbol.version_hidden?).to be false
    end

    it 'reads them from a file that has no sections left' do
      data = File.binread(File.join(__dir__, 'files', 'amd64.elf'))
      header = ELFTools::ELFFile.new(StringIO.new(data)).header
      header.e_shoff = 0
      header.e_shnum = 0
      header.e_shstrndx = 0
      data[0, header.num_bytes] = header.to_binary_s
      file = ELFTools::ELFFile.new(StringIO.new(data))
      expect(file.sections).to be_empty
      expect(file.dynamic.symbols.map(&:version)).to eq dynamic.symbols.map(&:version)
      expect(file.dynamic.version_requirements.first.file).to eq 'libc.so.6'
    end
  end
end
