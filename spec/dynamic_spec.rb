# frozen_string_literal: true

require 'stringio'

require 'elftools/elf_file'

describe ELFTools::Dynamic do
  def elf(name)
    ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name)))
  end

  # Reads +name+ with its section headers taken away, as a packer or a dumper
  # leaves a file that still runs.
  def elf_without_sections(name)
    data = File.binread(File.join(__dir__, 'files', name))
    header = ELFTools::ELFFile.new(StringIO.new(data)).header
    header.e_shoff = 0
    header.e_shnum = 0
    header.e_shstrndx = 0
    data[0, header.num_bytes] = header.to_binary_s
    ELFTools::ELFFile.new(StringIO.new(data))
  end

  before(:all) do
    filepath = File.join(__dir__, 'files', 'amd64.elf')
    @elf = ELFTools::ELFFile.new(File.open(filepath))
  end

  describe 'dynamic segment' do
    before(:all) do
      @segment = @elf.segment_by_type(:dynamic)
    end

    it 'tag_at' do
      expect(@segment.tag_at(0).header.d_tag).to eq 1
      expect(@segment.tag_at(-1)).to be nil
    end

    it 'tag_by_type' do
      expect(@segment.tag_by_type(:null).header.d_tag).to eq 0
      expect(@segment.tag_by_type(:pltgot).header.d_tag).to eq 3
      expect(@segment.tag_by_type('DT_SYMTAB').header.d_tag).to eq 6
      expect(@segment.tag_by_type('SymTab').header.d_tag).to eq 6

      expect { @segment.tag_by_type(1337) }.to raise_error(ArgumentError, 'No constants in Constants::DT is 1337')
      expect { @segment.tag_by_type(:xx) }.to raise_error(ArgumentError, 'No constants in Constants::DT named "DT_XX"')
    end

    it 'tags_by_type' do
      expect(@segment.tags_by_type(:needed).map(&:name)).to eq %w[libc.so.6]
    end

    it 'tags size' do
      expect(@segment.tags.size).to eq 24
    end

    it 'tags name' do
      expect(@segment.tag_by_type(:init).value).to be 0x400510
      expect(@segment.tag_by_type(:needed).value).to eq 'libc.so.6'
    end
  end

  describe 'relocations' do
    def from_sections(file)
      file.sections.select { |sec| sec.is_a?(ELFTools::Sections::RelocationSection) }.flat_map(&:relocations)
    end

    def summarize(relocations)
      relocations.map { |rel| [rel.header.r_offset.to_i, rel.symbol_index, rel.type_name] }
    end

    it 'reads what the sections record' do
      # Both views describe the same bytes, so each answers for the other.
      %w[amd64.elf i386.elf aarch64.elf ppc64.elf libc.so.6].each do |name|
        file = elf(name)
        expect(summarize(file.dynamic.relocations)).to eq summarize(from_sections(file))
        expect(file.dynamic.relocations).not_to be_empty
      end
    end

    it 'reads them from a file that has no sections left' do
      file = elf_without_sections('amd64.elf')
      expect(file.sections).to be_empty
      expect(summarize(file.dynamic.relocations)).to eq summarize(from_sections(elf('amd64.elf')))
    end

    it 'reports a table that is not loaded' do
      data = File.binread(File.join(__dir__, 'files', 'amd64.elf'))
      tag = ELFTools::ELFFile.new(StringIO.new(data)).dynamic.tag_by_type(:jmprel)
      tag.header.d_val = 0xdeadbeef000
      data[tag.header.offset, tag.header.num_bytes] = tag.header.to_binary_s
      file = ELFTools::ELFFile.new(StringIO.new(data))
      expect { file.dynamic.relocations }
        .to raise_error(ELFTools::ELFError, 'Invalid DT_JMPREL address 0xdeadbeef000')
    end
  end

  describe 'symbols' do
    it 'reads what .dynsym records' do
      # .dynsym describes the very bytes the tags point at, so it answers for
      # them, name for name and index for index. Every file here that is
      # loaded is checked, i.e. every one with dynamic tags.
      loaded = %w[aarch64.elf amd64.elf amd64.frelro.elf amd64.nrelro.elf amd64.strip.elf arm.elf
                  i386.elf i386.pie.elf i386.so.elf libc.so.6 ppc64.elf riscv64.elf]
      loaded.each do |name|
        file = elf(name)
        dynsym = file.section_by_name('.dynsym')
        expect(file.dynamic.num_symbols).to eq dynsym.num_symbols
        expect(file.dynamic.symbols.map(&:name)).to eq dynsym.symbols.map(&:name)
        expect(file.dynamic.symbols.map(&:header)).to eq dynsym.symbols.map(&:header)
      end
    end

    it 'counts what no single source of a count can' do
      # Neither source sees the whole table. A hash table only indexes the
      # defined symbols a file exports under a name, so ppc64.elf's reaches 1
      # of its 13; relocations only name the symbols something refers to, so
      # i386.so.elf's reach 16 of its 20. Together they have covered every
      # file here.
      expect(elf('ppc64.elf').dynamic.num_symbols).to eq 13
      expect(elf('i386.so.elf').dynamic.num_symbols).to eq 20
      # DT_HASH is the one tag that records the number outright.
      expect(elf('libc.so.6').dynamic.tag_by_type(:hash)).not_to be nil
      expect(elf('libc.so.6').dynamic.num_symbols).to eq 2245
    end

    it 'names the symbol a relocation points at' do
      dynamic = elf('amd64.elf').dynamic
      expect(dynamic.relocations.map { |rel| dynamic.symbol_at(rel.symbol_index).name }).to eq \
        %w[__gmon_start__ stdin puts __stack_chk_fail printf __libc_start_main fgets scanf]
    end

    it 'symbol_at' do
      dynamic = elf('amd64.elf').dynamic
      expect(dynamic.symbol_at(0).name).to eq ''
      expect(dynamic.symbol_at(1).name).to eq 'puts'
      expect(dynamic.symbol_at(1)).to be dynamic.symbol_at(1)
      expect(dynamic.symbol_at(-1)).to be nil
    end

    it 'symbol_by_name' do
      dynamic = elf('amd64.elf').dynamic
      expect(dynamic.symbol_by_name('printf').type_name).to eq 'STT_FUNC'
      expect(dynamic.symbol_by_name('no such symbol')).to be nil
    end

    it 'each_symbols' do
      dynamic = elf('amd64.elf').dynamic
      expect(dynamic.each_symbols).to be_a Enumerator
      expect(dynamic.each_symbols.map(&:name)).to eq dynamic.symbols.map(&:name)
    end

    it 'reads them from a file that has no sections left' do
      file = elf_without_sections('amd64.elf')
      expect(file.sections).to be_empty
      expect(file.dynamic.symbols.map(&:name)).to eq elf('amd64.elf').section_by_name('.dynsym').symbols.map(&:name)
    end

    it 'reports a table that is not there' do
      # Change the tag type so that DT_SYMTAB no longer exists.
      file = elf_with_patched_symtab { |header| header.d_tag = ELFTools::Constants::DT_DEBUG }
      expect { file.dynamic.symbol_at(0) }.to raise_error(ELFTools::ELFError, 'DT_SYMTAB not found')
    end

    it 'reports a table that is not loaded' do
      file = elf_with_patched_symtab { |header| header.d_val = 0xdeadbeef000 }
      expect { file.dynamic.symbol_at(0) }.to \
        raise_error(ELFTools::ELFError, 'Invalid DT_SYMTAB address 0xdeadbeef000')
    end

    # Returns an ELF file whose DT_SYMTAB tag has been modified by +block+.
    # @yieldparam [ELFTools::Structs::ELF_Dyn] header The DT_SYMTAB header.
    # @yieldreturn [void]
    # @return [ELFTools::ELFFile]
    def elf_with_patched_symtab
      data = File.binread(File.join(__dir__, 'files', 'amd64.elf'))
      header = ELFTools::ELFFile.new(StringIO.new(data)).dynamic.tag_by_type(:symtab).header
      yield header
      data[header.offset, header.num_bytes] = header.to_binary_s
      ELFTools::ELFFile.new(StringIO.new(data))
    end
  end

  describe 'broken DT_STRTAB' do
    # Returns an ELF file whose DT_STRTAB tag has been modified by +block+.
    # @yieldparam [ELFTools::Structs::ELF_Dyn] header The DT_STRTAB header.
    # @yieldreturn [void]
    # @return [ELFTools::ELFFile]
    def elf_with_patched_strtab
      data = File.binread(File.join(__dir__, 'files', 'amd64.elf'))
      header = ELFTools::ELFFile.new(StringIO.new(data)).segment_by_type(:dynamic).tag_by_type(:strtab).header
      yield header
      data[header.offset, header.num_bytes] = header.to_binary_s
      ELFTools::ELFFile.new(StringIO.new(data))
    end

    it 'tag not found' do
      # Change the tag type so that DT_STRTAB no longer exists.
      elf = elf_with_patched_strtab { |header| header.d_tag = ELFTools::Constants::DT_DEBUG }
      expect(elf.segment_by_type(:dynamic).tag_by_type(:strtab)).to be nil
      expect { elf.segment_by_type(:dynamic).tag_by_type(:needed).name }.to \
        raise_error(ELFTools::ELFError, 'DT_STRTAB not found')
      expect { elf.section_by_name('.dynamic').tag_by_type(:needed).name }.to \
        raise_error(ELFTools::ELFError, 'DT_STRTAB not found')
    end

    it 'address not loadable' do
      elf = elf_with_patched_strtab { |header| header.d_val = 0xdeadbeef000 }
      expect { elf.segment_by_type(:dynamic).tag_by_type(:needed).name }.to \
        raise_error(ELFTools::ELFError, 'Invalid DT_STRTAB address 0xdeadbeef000')
    end
  end

  describe 'dynamic section' do
    # Everything should same as dynamic segment,
    # let's just compare them.
    it 'same as segment' do
      from_section = @elf.section_by_name('.dynamic').tags.map(&:header)
      from_segment = @elf.segment_by_type(:dynamic).tags.map(&:header)
      expect(from_section).to eq from_segment
    end
  end
end
