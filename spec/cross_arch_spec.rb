# frozen_string_literal: true

require 'elftools/constants'
require 'elftools/elf_file'

describe 'cross architecture files' do
  def elf(name)
    ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name)))
  end

  {
    'aarch64.elf' => [64, :little, 'DYN', 'ARM 64-bit architecture'],
    'arm.elf' => [32, :little, 'DYN', 'ARM'],
    'arm.thumb.o' => [32, :little, 'REL', 'ARM'],
    'riscv64.elf' => [64, :little, 'DYN', 'RISC-V'],
    'ppc64.elf' => [64, :big, 'DYN', '64-bit PowerPC'],
    'mips.o' => [32, :big, 'REL', 'MIPS R3000'],
    'mips64.o' => [64, :big, 'REL', 'MIPS R3000'],
    'mips64el.o' => [64, :little, 'REL', 'MIPS R3000']
  }.each do |name, (elf_class, endian, type, machine)|
    it name do
      file = elf(name)
      expect(file.elf_class).to be elf_class
      expect(file.endian).to be endian
      expect(file.elf_type).to eq type
      expect(file.machine).to eq machine
    end
  end

  describe 'big endian' do
    it 'symbols' do
      main = elf('ppc64.elf').section_by_name('.symtab').symbol_by_name('main')
      expect(main.type).to be ELFTools::Constants::STT_FUNC
      expect(main.bind).to be ELFTools::Constants::STB_GLOBAL

      entry = elf('mips64.o').section_by_name('.symtab').symbol_by_name('entry')
      expect(entry.type).to be ELFTools::Constants::STT_FUNC
      expect(entry.section_index).not_to be ELFTools::Constants::SHN_UNDEF
    end

    it 'relocations' do
      rel = elf('ppc64.elf').sections_by_type(:rela).first.relocations.first
      expect(rel.header.r_offset.to_i).to be_positive
    end
  end

  describe 'the 64-bit MIPS ABI' do
    def relocations(name)
      elf(name).sections_by_type(:rela).flat_map do |sec|
        sec.relocations.map { |rel| [rel.symbol_index, rel.type_name] }
      end
    end

    # The ABI records more in r_info than the symbol index and the type every
    # machine records, and orders it all the way the file is ordered, so the
    # two ends of the field swap with the endianness.
    it 'reads a relocation the same whichever end the file starts from' do
      expect(relocations('mips64.o')).to eq relocations('mips64el.o')
    end

    %w[mips64.o mips64el.o].each do |name|
      it name do
        expect(relocations(name)).to include([8, 'R_MIPS_GPREL16'], [10, 'R_MIPS_CALL16'])
        num_symbols = elf(name).section_by_name('.symtab').num_symbols
        expect(relocations(name).map(&:first)).to all(be < num_symbols)
      end
    end
  end

  describe 'object files' do
    it 'records relocations to be resolved' do
      # Thumb shows up in relocations that a linker would have resolved.
      types = elf('arm.thumb.o').sections_by_type(:rel).flat_map { |s| s.relocations.map(&:type) }
      expect(types).not_to be_empty
    end
  end
end
