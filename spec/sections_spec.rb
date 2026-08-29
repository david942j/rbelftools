# encoding: ascii-8bit
# frozen_string_literal: true

require 'elftools/elf_file'
require 'elftools/sections/sections'
require 'elftools/structs'

describe ELFTools::Sections do
  before(:all) do
    @header_maker = lambda do |type: 0|
      # endian is not important
      shdr = ELFTools::Structs::ELF_Shdr.new(endian: :little)
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
  describe 'what a section is for' do
    before(:all) do
      filepath = File.join(__dir__, 'files', 'amd64.elf')
      @elf = ELFTools::ELFFile.new(File.open(filepath))
    end

    it 'says which are written to and which are executed' do
      expect(@elf.section_by_name('.text')).to be_executable
      expect(@elf.section_by_name('.text')).not_to be_writable
      expect(@elf.section_by_name('.data')).to be_writable
      expect(@elf.section_by_name('.data')).not_to be_executable
      expect(@elf.section_by_name('.rodata')).not_to be_writable
      expect(@elf.section_by_name('.rodata')).not_to be_executable
    end

    it 'says which take memory while the file runs' do
      # What the file is loaded by, against what is only recorded about it.
      expect(@elf.section_by_name('.text')).to be_allocated
      expect(@elf.section_by_name('.bss')).to be_allocated
      expect(@elf.section_by_name('.symtab')).not_to be_allocated
      expect(@elf.section_by_name('.shstrtab')).not_to be_allocated
    end

    it 'says the same of a section of any file' do
      # A section taking memory is a section a segment takes memory for, so
      # the two views have to agree. What is compared is the memory a segment
      # takes and not the bytes it is read from, .bss taking the one without
      # occupying any of the other.
      %w[amd64.elf ppc64.elf i386.pie.elf].each do |name|
        elf = ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name)))
        loaded = elf.segments_by_type(:load)
        elf.sections.each do |section|
          address = section.header.sh_addr.to_i
          next if section.null? || address.zero?

          covered = loaded.any? { |seg| address >= seg.mem_head && address < seg.mem_tail }
          expect(section.allocated?).to be covered
        end
      end
    end
  end
end
