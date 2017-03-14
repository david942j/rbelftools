# encoding: ascii-8bit
require 'elftools/sections/sections'
require 'elftools/structures'
describe ELFTools::Section do
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
      section = ELFTools::Section.create(@header_maker.call(type: 0xdeadbeef), nil)
      expect(section).to be_a ELFTools::Section
      expect(section.null?).to be false
    end

    it 'null' do
      null = ELFTools::Section.create(@header_maker.call, nil)
      expect(null).to be_a ELFTools::NullSection
      expect(null.null?).to be true
    end

    it 'strtab' do
      strtab = ELFTools::Section.create(@header_maker.call(type: 3), nil)
      expect(strtab).to be_a ELFTools::StrTabSection
      expect(strtab.respond_to?(:name_at)).to be true
    end

    it 'symtab' do
      symtab = ELFTools::Section.create(@header_maker.call(type: 2), nil)
      expect(symtab).to be_a ELFTools::SymTabSection
      expect(symtab.respond_to?(:symbols)).to be true
    end
  end
end
