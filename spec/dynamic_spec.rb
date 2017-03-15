require 'elftools/elf_file'

describe ELFTools::Dynamic do
  before(:all) do
    filepath = File.join(__dir__, 'files', 'amd64')
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

      expect { @segment.tag_by_type(1337) }.to raise_error(ArgumentError, 'No DT type is "1337"')
      expect { @segment.tag_by_type(:oao) }.to raise_error(ArgumentError, 'No DT type named "DT_OAO"')
    end

    it 'tags size' do
      expect(@segment.tags.size).to eq 24
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
