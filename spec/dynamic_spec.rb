# frozen_string_literal: true

require 'stringio'

require 'elftools/elf_file'

describe ELFTools::Dynamic do
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
    def elf(name)
      ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name)))
    end

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
      data = File.binread(File.join(__dir__, 'files', 'amd64.elf'))
      header = ELFTools::ELFFile.new(StringIO.new(data)).header
      header.e_shoff = 0
      header.e_shnum = 0
      header.e_shstrndx = 0
      data[0, header.num_bytes] = header.to_binary_s
      file = ELFTools::ELFFile.new(StringIO.new(data))
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
