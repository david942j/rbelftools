# frozen_string_literal: true

require 'stringio'

require 'elftools/elf_file'

describe ELFTools::Dynamic do
  def elf(name)
    ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name)))
  end

  # Returns an ELF file whose tag of +type+ has been modified by +block+.
  # @param [Symbol] type The type of the tag.
  # @yieldparam [ELFTools::Structs::ELF_Dyn] header The header of the tag.
  # @yieldreturn [void]
  # @return [ELFTools::ELFFile]
  def elf_with_patched_tag(type)
    data = File.binread(File.join(__dir__, 'files', 'amd64.elf'))
    header = ELFTools::ELFFile.new(StringIO.new(data)).dynamic.tag_by_type(type).header
    yield header
    data[header.offset, header.num_bytes] = header.to_binary_s
    ELFTools::ELFFile.new(StringIO.new(data))
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

    it 'names what kind of tag it is' do
      expect(@segment.tag_by_type(:needed).type).to be ELFTools::Constants::DT_NEEDED
      expect(@segment.tag_at(0).type).to be ELFTools::Constants::DT_NEEDED
      expect(@segment.tags.last.type).to be ELFTools::Constants::DT_NULL
    end

    it 'reads what a tag records without building a structure for it' do
      # A structure of its own for every tag costs over two hundred objects
      # each, which looking a tag up used to be spent on.
      dynamic = ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', 'libc.so.6'))).dynamic
      before = GC.stat(:total_allocated_objects)
      dynamic.tags_by_type(:needed)
      expect(GC.stat(:total_allocated_objects) - before).to be < (50 * dynamic.tags.size)
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

    it 'reads a table once' do
      dynamic = elf('libc.so.6').dynamic
      expect(dynamic.relocations).to be dynamic.relocations
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

    it 'stops at the table that counts the symbols' do
      # DT_HASH counts every symbol, so nothing else a file records reaches
      # past it and reading every relocation to find that out would be work
      # for nothing.
      dynamic = elf('libc.so.6').dynamic
      expect(dynamic.tag_by_type(:hash)).not_to be nil
      expect(dynamic).not_to receive(:relocations)
      expect(dynamic.num_symbols).to eq 2245
    end

    it 'reaches for the relocations only where nothing counts the symbols' do
      dynamic = elf('ppc64.elf').dynamic
      expect(dynamic.tag_by_type(:hash)).to be nil
      expect(dynamic).to receive(:relocations).and_call_original
      expect(dynamic.num_symbols).to eq 13
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

    it 'each_symbol' do
      dynamic = elf('amd64.elf').dynamic
      expect(dynamic.each_symbol).to be_a Enumerator
      expect(dynamic.each_symbol.map(&:name)).to eq dynamic.symbols.map(&:name)
    end

    it 'reads them from a file that has no sections left' do
      file = elf_without_sections('amd64.elf')
      expect(file.sections).to be_empty
      expect(file.dynamic.symbols.map(&:name)).to eq elf('amd64.elf').section_by_name('.dynsym').symbols.map(&:name)
    end

    it 'reports a table that is not there' do
      # Change the tag type so that DT_SYMTAB no longer exists.
      file = elf_with_patched_tag(:symtab) { |header| header.d_tag = ELFTools::Constants::DT_DEBUG }
      expect { file.dynamic.symbol_at(0) }.to raise_error(ELFTools::ELFError, 'DT_SYMTAB not found')
    end

    it 'reports a table that is not loaded' do
      file = elf_with_patched_tag(:symtab) { |header| header.d_val = 0xdeadbeef000 }
      expect { file.dynamic.symbol_at(0) }.to \
        raise_error(ELFTools::ELFError, 'Invalid DT_SYMTAB address 0xdeadbeef000')
    end
  end

  describe 'symbol_by_name' do
    it 'finds every name a file records' do
      # Whatever a table leads to and whatever it does not, the answer is the
      # symbol that bears the name.
      %w[aarch64.elf amd64.elf arm.elf i386.elf i386.pie.elf i386.so.elf
         libc.so.6 ppc64.elf riscv64.elf].each do |name|
        dynamic = elf(name).dynamic
        names = dynamic.symbols.map(&:name).reject(&:empty?).uniq
        expect(names).not_to be_empty
        expect(names.reject { |sym| dynamic.symbol_by_name(sym)&.name == sym }).to be_empty
      end
    end

    it 'reads the table of whichever kind a file records' do
      expect(elf('libc.so.6').dynamic.send(:hash_tables).map(&:class)).to eq \
        [ELFTools::Dynamic::HashTable::SysV, ELFTools::Dynamic::HashTable::Gnu]
      # A file built the way the toolchain builds them today records only the
      # GNU one.
      expect(elf('amd64.elf').dynamic.send(:hash_tables).map(&:class)).to eq \
        [ELFTools::Dynamic::HashTable::Gnu]
    end

    it 'looks a name up instead of searching for it' do
      dynamic = elf('libc.so.6').dynamic
      # Searching would mean reading all 2245 symbols to reach this one.
      expect(dynamic).not_to receive(:each_symbol)
      expect(dynamic.symbol_by_name('malloc').name).to eq 'malloc'
    end

    it 'searches for a name no table leads to' do
      # A table only indexes the symbols a file exports, so the ones an
      # executable imports are not in it.
      dynamic = elf('amd64.elf').dynamic
      expect(dynamic.send(:hash_tables).map { |table| table.index_of('printf') { true } }).to eq [nil]
      expect(dynamic.symbol_by_name('printf').name).to eq 'printf'
    end

    it 'searches a file that records no table at all' do
      # Change the tag type so that DT_GNU_HASH no longer exists.
      file = elf_with_patched_tag(:gnu_hash) { |header| header.d_tag = ELFTools::Constants::DT_DEBUG }
      expect(file.dynamic.send(:hash_tables)).to be_empty
      expect(file.dynamic.symbol_by_name('printf').name).to eq 'printf'
      expect(file.dynamic.symbol_by_name('no such symbol')).to be nil
    end

    it 'reports a name that is nowhere' do
      expect(elf('libc.so.6').dynamic.symbol_by_name('no such symbol')).to be nil
      expect(elf('amd64.elf').dynamic.symbol_by_name('no such symbol')).to be nil
    end

    it 'stops at a table built over every symbol rather than searching' do
      # DT_HASH is built over the whole symbol table, so a name it does not
      # lead to is not one the file records and searching for it would read
      # all 2245 symbols to answer what the table already has.
      dynamic = elf('libc.so.6').dynamic
      expect(dynamic.send(:hash_tables).any?(&:covers_every_symbol?)).to be true
      expect(dynamic).not_to receive(:each_symbol)
      expect(dynamic.symbol_by_name('no such symbol')).to be nil
    end

    it 'searches for the symbol that has no name' do
      # It is the one symbol such a table leaves out, having nothing to be
      # indexed by, so it is still searched for.
      dynamic = elf('libc.so.6').dynamic
      expect(dynamic.send(:hash_tables).any?(&:covers_every_symbol?)).to be true
      expect(dynamic).to receive(:each_symbol).at_least(:once).and_call_original
      expect(dynamic.symbol_by_name('').value).to eq 0
    end

    it 'still searches where no table is built over every symbol' do
      # The GNU table only indexes the defined symbols a file exports, so a
      # name it does not lead to may still be in the table.
      dynamic = elf('amd64.elf').dynamic
      expect(dynamic.send(:hash_tables).any?(&:covers_every_symbol?)).to be false
      expect(dynamic).to receive(:each_symbol).at_least(:once).and_call_original
      expect(dynamic.symbol_by_name('no such symbol')).to be nil
    end
  end

  describe 'broken DT_STRTAB' do
    it 'tag not found' do
      # Change the tag type so that DT_STRTAB no longer exists.
      elf = elf_with_patched_tag(:strtab) { |header| header.d_tag = ELFTools::Constants::DT_DEBUG }
      expect(elf.segment_by_type(:dynamic).tag_by_type(:strtab)).to be nil
      expect { elf.segment_by_type(:dynamic).tag_by_type(:needed).name }.to \
        raise_error(ELFTools::ELFError, 'DT_STRTAB not found')
      expect { elf.section_by_name('.dynamic').tag_by_type(:needed).name }.to \
        raise_error(ELFTools::ELFError, 'DT_STRTAB not found')
    end

    it 'address not loadable' do
      elf = elf_with_patched_tag(:strtab) { |header| header.d_val = 0xdeadbeef000 }
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
