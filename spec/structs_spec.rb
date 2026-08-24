# frozen_string_literal: true

require 'elftools/elf_file'

describe ELFTools::Structs::ELFStruct do
  def header(name = 'amd64.elf')
    ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name))).header
  end

  describe 'patches' do
    it 'reports nothing while nothing has changed' do
      expect(header.patches).to eq({})
    end

    it 'reports a field however deeply it is nested' do
      hdr = header
      # EI_ABIVERSION is the ninth byte of what e_ident records, and e_ident is
      # a structure of its own, which nothing used to be able to patch.
      hdr.e_ident.ei_abiversion = 41
      expect(hdr.patches).to eq({ 8 => 41.chr })
    end

    it 'reports nothing for a field assigned what it already held' do
      hdr = header
      hdr.e_machine = ELFTools::Constants::EM_ARM
      hdr.e_machine = ELFTools::Constants::EM_X86_64
      expect(hdr.patches).to eq({})
    end

    it 'reports each run of changed bytes on its own' do
      hdr = header
      hdr.e_ident.ei_osabi = 3
      hdr.e_machine = ELFTools::Constants::EM_ARM
      expect(hdr.patches).to eq({ 7 => 3.chr, 18 => 40.chr })
    end

    it 'orders the bytes the way the file it was read from does' do
      # The same assignment, of a number whose halves differ, reaches a
      # different byte of the field in a file ordered the other way.
      expect(header('amd64.elf').tap { |hdr| hdr.e_machine = 40 }.patches).to eq({ 18 => 40.chr })
      expect(header('ppc64.elf').tap { |hdr| hdr.e_machine = 40 }.patches).to eq({ 19 => 40.chr })
    end

    it 'reports nothing for a structure that was never read' do
      expect(ELFTools::Structs::ELF_Dyn.new(endian: :little).patches).to eq({})
    end
  end

  describe '.pack' do
    it 'packs an integer the way the class it is asked of is ordered' do
      expect(ELFTools::Structs::ELF_DynLe.pack(0x0102, 2)).to eq "\x02\x01".b
      expect(ELFTools::Structs::ELF_DynBe.pack(0x0102, 2)).to eq "\x01\x02".b
      expect { ELFTools::Structs::ELF_DynLe.pack('x', 2) }
        .to raise_error(ArgumentError, 'Not supported assign type String')
    end
  end
end
