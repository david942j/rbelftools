# encoding: ascii-8bit
# frozen_string_literal: true

require 'elftools/segments/segments'
require 'elftools/structs'

describe ELFTools::Segments do
  before(:all) do
    @header_maker = lambda do |type: 0, flags: 0|
      # endian is not important
      phdr = ELFTools::Structs::ELF_Phdr[32].new(endian: :little)
      phdr.assign(p_type: type, p_flags: flags)
      phdr
    end
  end

  describe 'type of segments' do
    it 'normal' do
      segment = ELFTools::Segments::Segment.create(@header_maker.call(type: 0xdeadbeef), nil)
      expect(segment).to be_a ELFTools::Segments::Segment
    end

    it 'note' do
      note = ELFTools::Segments::Segment.create(@header_maker.call(type: 4), nil)
      expect(note).to be_a ELFTools::Segments::NoteSegment
      expect(note.respond_to?(:notes)).to be true
    end

    it 'interp' do
      interp = ELFTools::Segments::Segment.create(@header_maker.call(type: 3), nil)
      expect(interp).to be_a ELFTools::Segments::InterpSegment
      expect(interp.respond_to?(:interp_name)).to be true
    end

    it 'dynamic' do
      dynamic = ELFTools::Segments::Segment.create(@header_maker.call(type: 2), nil)
      expect(dynamic).to be_a ELFTools::Segments::DynamicSegment
      expect(dynamic.respond_to?(:tags)).to be true
    end

    it 'load' do
      load_seg = ELFTools::Segments::Segment.create(@header_maker.call(type: 1), nil)
      expect(load_seg).to be_a ELFTools::Segments::LoadSegment
      expect(load_seg.respond_to?(:vma_to_offset)).to be true
    end
  end

  describe 'load segment' do
    before(:all) do
      # Same values as the data segment of spec/files/amd64.elf, whose file
      # content ends at 0x601058 while it occupies memory until 0x6010f0.
      @load_maker = lambda do |p_offset: 0xe10|
        phdr = ELFTools::Structs::ELF_Phdr[32].new(endian: :little)
        phdr.assign(p_type: 1, p_offset:, p_vaddr: 0x600e10,
                    p_filesz: 0x248, p_memsz: 0x2e0, p_align: 0x200000)
        ELFTools::Segments::Segment.create(phdr, nil)
      end
    end

    it 'offset_in?' do
      segment = @load_maker.call
      expect(segment.offset_in?(0xe0f)).to be false
      expect(segment.offset_in?(0xe10)).to be true
      # The last byte in file belongs to this segment.
      expect(segment.offset_in?(0x1057, 1)).to be true
      expect(segment.offset_in?(0x1057, 2)).to be false
    end

    it 'vma_in?' do
      segment = @load_maker.call
      # Addresses sharing an alignment unit with p_vaddr are mapped from file as well.
      expect(segment.mapped_head).to be 0x600000
      expect(segment.vma_in?(0x5fffff)).to be false
      expect(segment.vma_in?(0x600000)).to be true
      expect(segment.vma_to_offset(0x600000)).to be 0
    end

    it 'addresses without content in file' do
      segment = @load_maker.call
      expect(segment.mapped_tail).to be 0x601058
      expect(segment.mem_tail).to be 0x6010f0
      expect(segment.vma_in?(0x601057, 1)).to be true
      expect(segment.vma_in?(0x601058, 1)).to be false
      expect(segment.vma_in?(0x6010ef)).to be false
    end

    it 'p_offset not aligned with p_vaddr' do
      # Invalid according to the ELF spec, the conversion should still be sane.
      segment = @load_maker.call(p_offset: 0x100)
      expect(segment.offset_to_vma(0x100)).to be 0x600e10
      expect(segment.offset_to_vma(0x180)).to be 0x600e90
      # Never converts into a negative file offset.
      expect(segment.mapped_head).to be 0x600d10
      expect(segment.vma_to_offset(segment.mapped_head)).to be 0
      expect(segment.vma_in?(0x600000)).to be false
    end
  end

  describe 'common methods' do
    it 'permission' do
      rx = ELFTools::Segments::Segment.new(@header_maker.call(flags: 5), nil)
      expect(rx.readable? && !rx.writable? && rx.executable?).to be true
      w = ELFTools::Segments::Segment.new(@header_maker.call(flags: 2), nil)
      expect(!w.readable? && w.writable? && !w.executable?).to be true
    end
  end
end
