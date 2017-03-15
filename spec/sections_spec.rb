# encoding: ascii-8bit
require 'elftools/sections/sections'
require 'elftools/structures'
describe ELFTools::Sections do
  before(:all) do
    @header_maker = lambda do |type: 0|
      # endian is not important
      shdr = ELFTools::ELF_Shdr.new(endian: :little)
      shdr.assign(sh_type: type)
      shdr
    end
  end
  describe 'type of sections' do
    it 'normal' do
      section = ELFTools::Sections::Section.create(@header_maker.call(type: 0xdeadbeef), nil)
      expect(section).to be_a ELFTools::Sections::Section
      expect(section.null?).to be false
    end

    it 'null' do
      null = ELFTools::Sections::Section.create(@header_maker.call, nil)
      expect(null).to be_a ELFTools::Sections::NullSection
      expect(null.null?).to be true
    end

    it 'strtab' do
      strtab = ELFTools::Sections::Section.create(@header_maker.call(type: 3), nil)
      expect(strtab).to be_a ELFTools::Sections::StrTabSection
      expect(strtab.respond_to?(:name_at)).to be true
    end

    it 'symtab' do
      symtab = ELFTools::Sections::Section.create(@header_maker.call(type: 2), nil)
      expect(symtab).to be_a ELFTools::Sections::SymTabSection
      expect(symtab.respond_to?(:symbols)).to be true
    end

    it 'note' do
      note = ELFTools::Sections::Section.create(@header_maker.call(type: 7), nil)
      expect(note).to be_a ELFTools::Sections::NoteSection
      expect(note.respond_to?(:notes)).to be true
    end
  end
end
