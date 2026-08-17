# frozen_string_literal: true

require 'elftools/constants'
require 'elftools/elf_file'

describe ELFTools::Constants::R do
  it 'numbers relocations per architecture' do
    r = described_class
    # The very same number is a different relocation on every architecture,
    # which is why they are not defined in one place.
    expect(r::X86_64::R_X86_64_JUMP_SLOT).to be 7
    expect(r::I386::R_386_JUMP_SLOT).to be 7
    expect(r::ARM::R_ARM_THM_ABS5).to be 7
    expect(r::RISCV::R_RISCV_TLS_DTPMOD64).to be 7
  end

  it 'covers what a file records' do
    filepath = File.join(__dir__, 'files', 'aarch64.elf')
    elf = ELFTools::ELFFile.new(File.open(filepath))
    types = elf.sections_by_type(:rela).flat_map { |sec| sec.relocations.map(&:type) }.uniq
    expect(types).to contain_exactly(described_class::AARCH64::R_AARCH64_GLOB_DAT,
                                     described_class::AARCH64::R_AARCH64_JUMP_SLOT,
                                     described_class::AARCH64::R_AARCH64_RELATIVE)
  end

  it 'defines every architecture it lists' do
    architectures = described_class.constants - [:MACHINES]
    expect(architectures.size).to be > 70
    expect(architectures.map { |name| described_class.const_get(name) }).to all(be_a(Module))
  end

  describe 'mapping' do
    it 'names a type after the machine that recorded it' do
      expect(described_class.mapping(ELFTools::Constants::EM_X86_64, 7)).to eq 'R_X86_64_JUMP_SLOT'
      expect(described_class.mapping(ELFTools::Constants::EM_386, 7)).to eq 'R_386_JUMP_SLOT'
      expect(described_class.mapping(ELFTools::Constants::EM_ARM, 7)).to eq 'R_ARM_THM_ABS5'
    end

    it 'gives up on what it cannot name' do
      # A machine that relocates nothing, and a type no architecture defines.
      expect(described_class.mapping(ELFTools::Constants::EM_NONE, 7)).to eq '<unknown>: 0x7'
      expect(described_class.mapping(nil, 7)).to eq '<unknown>: 0x7'
      expect(described_class.mapping(ELFTools::Constants::EM_X86_64, 1337)).to eq '<unknown>: 0x539'
    end

    it 'relocates a machine whose name differs from the architecture' do
      # binutils keeps the i386 relocations in i386.h, but calls the machine EM_386.
      expect(described_class::MACHINES[ELFTools::Constants::EM_386]).to be :I386
      expect(described_class::MACHINES[ELFTools::Constants::EM_PARISC]).to be :HPPA
    end
  end

  describe 'type_name' do
    def type_names(name)
      elf = ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name)))
      sections = elf.sections_by_type(:rela) + elf.sections_by_type(:rel)
      sections.flat_map { |sec| sec.relocations.map(&:type_name) }
    end

    it 'names the relocations of a file' do
      %w[amd64.elf i386.elf aarch64.elf arm.elf riscv64.elf ppc64.elf].each do |name|
        expect(type_names(name)).to all(start_with('R_'))
      end
    end

    it 'tells apart the same type on different machines' do
      # Both files record the type as 7, each meaning its own relocation.
      expect(type_names('amd64.elf')).to include('R_X86_64_JUMP_SLOT')
      expect(type_names('i386.elf')).to include('R_386_JUMP_SLOT')
      expect(type_names('arm.thumb.o')).to include('R_ARM_THM_CALL')
    end
  end
end
