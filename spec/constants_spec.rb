# frozen_string_literal: true

require 'elftools/constants'

describe ELFTools::Constants do
  it 'check scope' do
    # Just make sure the methods in submodule didn't extend to Constants.
    expect(ELFTools::Constants.respond_to?(:mapping)).to be false
  end

  it ELFTools::Constants::EM do
    em = ELFTools::Constants::EM
    expect(em.mapping(1337)).to eq '<unknown>: 0x539'
    expect(em.mapping(0)).to eq 'None'
    expect(em.mapping(3)).to eq 'Intel 80386'
    expect(em.mapping(7)).to eq 'Intel 80860'
    expect(em.mapping(8)).to eq 'MIPS R3000'
    expect(em.mapping(20)).to eq 'PowerPC'
    expect(em.mapping(21)).to eq 'PowerPC64'
    expect(em.mapping(40)).to eq 'ARM'
    expect(em.mapping(50)).to eq 'Intel IA-64'
    expect(em.mapping(62)).to eq 'Advanced Micro Devices X86-64'
    expect(em.mapping(183)).to eq 'AArch64'
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
end
