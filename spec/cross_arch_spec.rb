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
    'mips64.o' => [64, :big, 'REL', 'MIPS R3000']
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

      # The symbol index is the high half of r_info on every 64-bit target.
      rels = elf('mips64.o').sections_by_type(:rela).first.relocations
      expect(rels.map(&:symbol_index)).to all(be < elf('mips64.o').section_by_name('.symtab').num_symbols)
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
