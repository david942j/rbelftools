# frozen_string_literal: true

require 'elftools/elf_file'

describe ELFTools::Relocation do
  def relocations(name)
    elf = ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', name)))
    (elf.sections_by_type(:rel) + elf.sections_by_type(:rela)).flat_map(&:relocations)
  end

  # A REL relocation records no addend, the content it relocates carries one
  # instead, so both kinds answer for an addend and only one answers with a
  # number.
  it 'reads either kind of relocation' do
    rel = relocations('i386.elf')
    expect(rel).not_to be_empty
    expect(rel.map { |r| r.header.r_addend }).to all(be_nil)

    addends = relocations('aarch64.elf').map { |r| r.header.r_addend&.to_i }
    expect(addends).to all(be_an(Integer))
    expect(addends).to include(be_positive)
  end

  # Writing back what was read changes nothing, whatever the layout, which is
  # what says the two halves are being put back where they came from.
  it 'writes each half back where it was read from' do
    %w[i386.elf amd64.elf aarch64.elf mips64.o mips64el.o].each do |name|
      rels = relocations(name)
      expect(rels).not_to be_empty
      rels.each do |rel|
        before = rel.header.r_info.to_i
        wanted = [rel.symbol_index, rel.type]
        rel.symbol_index = wanted.first
        rel.type = wanted.last
        expect(rel.header.r_info.to_i).to eq before
        expect([rel.symbol_index, rel.type]).to eq wanted
      end
    end
  end

  it 'leaves the bytes the 64-bit MIPS ABI keeps for itself alone' do
    # 0x0518 of each is the ABI's, and the two files record the very same
    # relocation the two ways round.
    big = relocations('mips64.o').first
    big.symbol_index = 9
    big.type = 5
    expect(big.header.r_info.to_i).to eq 0x0000_0009_0005_1805

    little = relocations('mips64el.o').first
    little.symbol_index = 9
    little.type = 5
    expect(little.header.r_info.to_i).to eq 0x0518_0500_0000_0009
  end

  it 'takes a structure a caller has built itself' do
    # What {Relocation.new} has always taken, kept working for whoever builds
    # a relocation of their own rather than reading one out of a file.
    struct = ELFTools::Structs::ELF_Rela.new(endian: :little)
    struct.elf_class = 64
    struct.r_info = (3 << 32) | 7
    rel = ELFTools::Relocation.new(struct, nil, machine: ELFTools::Constants::EM_X86_64)
    expect([rel.symbol_index, rel.type, rel.type_name]).to eq [3, 7, 'R_X86_64_JUMP_SLOT']
    expect(rel.header).to equal struct
    # Assigning reaches the very structure it was given.
    rel.type = ELFTools::Constants::R::X86_64::R_X86_64_GLOB_DAT
    expect(struct.r_info.to_i).to eq((3 << 32) | ELFTools::Constants::R::X86_64::R_X86_64_GLOB_DAT)
  end

  it 'reports a value the bits recording it cannot hold' do
    # A 32-bit file leaves a type one byte and a symbol index the other three.
    rel = relocations('i386.elf').first
    expect { rel.type = 256 }.to raise_error(ArgumentError, 'Relocation type must be in 0..255, got 256')
    expect { rel.symbol_index = 1 << 24 }
      .to raise_error(ArgumentError, 'Symbol index must be in 0..16777215, got 16777216')
    # A 64-bit one halves it instead.
    expect { relocations('amd64.elf').first.type = 1 << 32 }
      .to raise_error(ArgumentError, 'Relocation type must be in 0..4294967295, got 4294967296')
  end
end
