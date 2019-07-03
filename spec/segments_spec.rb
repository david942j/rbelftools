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

  describe 'common methods' do
    it 'permission' do
      rx = ELFTools::Segments::Segment.new(@header_maker.call(flags: 5), nil)
      expect(rx.readable? && !rx.writable? && rx.executable?).to be true
      w = ELFTools::Segments::Segment.new(@header_maker.call(flags: 2), nil)
      expect(!w.readable? && w.writable? && !w.executable?).to be true
    end
  end
end
