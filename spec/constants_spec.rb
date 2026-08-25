# frozen_string_literal: true

require 'elftools/constants'
require 'elftools/elf_file'

describe ELFTools::Constants do
  it 'check scope' do
    # Just make sure the methods in submodule didn't extend to Constants.
    expect(ELFTools::Constants.respond_to?(:mapping)).to be false
  end

  it ELFTools::Constants::EM do
    em = ELFTools::Constants::EM
    expect(em.mapping(1337)).to eq '<unknown>: 0x539'
    expect(em.mapping(0)).to eq 'No machine'
    expect(em.mapping(3)).to eq 'Intel 80386'
    expect(em.mapping(7)).to eq 'Intel 80860'
    expect(em.mapping(8)).to eq 'MIPS R3000'
    expect(em.mapping(20)).to eq 'PowerPC'
    expect(em.mapping(21)).to eq '64-bit PowerPC'
    expect(em.mapping(40)).to eq 'ARM'
    expect(em.mapping(50)).to eq 'Intel IA-64 Processor'
    expect(em.mapping(62)).to eq 'Advanced Micro Devices X86-64 processor'
    expect(em.mapping(183)).to eq 'ARM 64-bit architecture'

    # Machines named by elf.h only.
    expect(em.mapping(2)).to eq 'SUN SPARC'
    expect(em.mapping(22)).to eq 'IBM S/390'
    expect(em.mapping(243)).to eq 'RISC-V'
    expect(em.mapping(258)).to eq 'LoongArch'
  end

  it ELFTools::Constants::ET do
    et = ELFTools::Constants::ET
    expect(et.mapping(1337)).to eq '<unknown>'
    expect(et.mapping(0)).to eq 'NONE'
    expect(et.mapping(1)).to eq 'REL'
    expect(et.mapping(2)).to eq 'EXEC'
    expect(et.mapping(3)).to eq 'DYN'
    expect(et.mapping(4)).to eq 'CORE'
  end

  describe ELFTools::Constants::Naming do
    let(:c) { ELFTools::Constants }

    it 'names a value after the machine that defines it' do
      # 13 is a type each of these machines defines for itself.
      expect(c::STT.mapping(c::EM_ARM, 13)).to eq 'STT_ARM_TFUNC'
      expect(c::STT.mapping(c::EM_SPARC, 13)).to eq 'STT_SPARC_REGISTER'
      expect(c::SHN.mapping(c::EM_MIPS, 0xff02)).to eq 'SHN_MIPS_DATA'
      expect(c::SHN.mapping(c::EM_X86_64, 0xff02)).to eq 'SHN_X86_64_LCOMMON'
    end

    it 'passes over the names of another machine' do
      expect(c::STT.mapping(c::EM_X86_64, 13)).to eq '<unknown>: 0xd'
      expect(c::SHN.mapping(c::EM_ARM, 0xff02)).to eq '<unknown>: 0xff02'
      # Nothing names a value when the machine is unknown either.
      expect(c::STT.mapping(nil, 13)).to eq '<unknown>: 0xd'
    end

    it 'passes over a name marking a range or a count' do
      # STT_LOOS and STB_LOOS mark where a range begins, the value is named
      # after what defines it. STT_NUM and SHN_LORESERVE only ever mark.
      expect(c::STT.mapping(c::EM_X86_64, 10)).to eq 'STT_GNU_IFUNC'
      expect(c::STB.mapping(c::EM_X86_64, 10)).to eq 'STB_GNU_UNIQUE'
      expect(c::SHN.mapping(c::EM_X86_64, 0xffff)).to eq 'SHN_XINDEX'
      expect(c::STT.mapping(c::EM_X86_64, 7)).to eq '<unknown>: 0x7'
      expect(c::SHN.mapping(c::EM_X86_64, 0xff00)).to eq '<unknown>: 0xff00'
    end

    it 'names what only one constant defines' do
      expect(c::STT.mapping(c::EM_X86_64, 2)).to eq 'STT_FUNC'
      expect(c::STB.mapping(c::EM_X86_64, 0)).to eq 'STB_LOCAL'
      expect(c::STV.mapping(c::EM_X86_64, 2)).to eq 'STV_HIDDEN'
      expect(c::SHN.mapping(c::EM_X86_64, 0xfff1)).to eq 'SHN_ABS'
    end
  end
  describe 'R.relative' do
    it 'names the type each machine calls a relative relocation' do
      # What every file recording one of them actually records, so the answer
      # is checked against the files rather than against the constants alone.
      {
        'amd64.elf' => 'R_X86_64_RELATIVE', 'i386.pie.elf' => 'R_386_RELATIVE',
        'aarch64.elf' => 'R_AARCH64_RELATIVE', 'arm.elf' => 'R_ARM_RELATIVE',
        'riscv64.elf' => 'R_RISCV_RELATIVE', 'ppc64.elf' => 'R_PPC64_RELATIVE'
      }.each do |name, expected|
        elf = ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name)))
        machine = elf.header.e_machine.to_i
        type = ELFTools::Constants::R.relative(machine)
        expect(ELFTools::Constants::R.mapping(machine, type)).to eq expected
        recorded = elf.dynamic.relocations.find { |rel| rel.type_name == expected }
        expect(recorded.type).to eq type unless recorded.nil?
      end
    end

    it 'reports nothing for a machine naming no such relocation' do
      # A machine of its own, and one with no relocation types at all.
      expect(ELFTools::Constants::R.relative(nil)).to be nil
      expect(ELFTools::Constants::R.relative(ELFTools::Constants::EM_WEBASSEMBLY)).to be nil
    end
  end
end
