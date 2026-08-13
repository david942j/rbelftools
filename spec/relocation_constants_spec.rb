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
    architectures = described_class.constants
    expect(architectures.size).to be > 70
    expect(architectures.map { |name| described_class.const_get(name) }).to all(be_a(Module))
  end
end
