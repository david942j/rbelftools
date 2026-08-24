# frozen_string_literal: true

require 'elftools/util'

describe ELFTools::Util do
  it 'align' do
    expect(ELFTools::Util.align(10, 1)).to be 10
    expect(ELFTools::Util.align(10, 2)).to be 12
    expect(ELFTools::Util.align(10, 3)).to be 16
    expect(ELFTools::Util.align(10, 4)).to be 16
    expect(ELFTools::Util.align(10, 5)).to be 32
    expect(ELFTools::Util.align(7, 0)).to be 7
    expect(ELFTools::Util.align(7, 1)).to be 8
    expect(ELFTools::Util.align(7, 2)).to be 8
  end

  it 'fits!' do
    expect(ELFTools::Util.fits!(15, 4, 'Thing')).to be 15
    expect(ELFTools::Util.fits!(0, 1, 'Thing')).to be 0
    expect { ELFTools::Util.fits!(16, 4, 'Thing') }
      .to raise_error(ArgumentError, 'Thing must be in 0..15, got 16')
    expect { ELFTools::Util.fits!(-1, 4, 'Thing') }
      .to raise_error(ArgumentError, 'Thing must be in 0..15, got -1')
    expect { ELFTools::Util.fits!(nil, 4, 'Thing') }
      .to raise_error(ArgumentError, 'Thing must be in 0..15, got nil')
  end
end
