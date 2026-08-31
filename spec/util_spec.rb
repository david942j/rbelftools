# frozen_string_literal: true

require 'stringio'

require 'elftools/constants'
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

  describe 'cstring' do
    def cstring(data, offset)
      io = StringIO.new(data)
      [ELFTools::Util.cstring(io, offset), io.pos]
    end

    it 'reads up to the null-byte and stops just past it' do
      expect(cstring("abc\0def\0", 0)).to eq ['abc', 4]
      expect(cstring("abc\0def\0", 4)).to eq ['def', 8]
      expect(cstring("\0abc\0", 0)).to eq ['', 1]
    end

    it 'reads a name of any length, however the chunks fall' do
      # A name is taken in chunks, so the bytes either side of a chunk's end
      # are where a name would be cut short or run on.
      (ELFTools::Util::CSTRING_CHUNK - 1..ELFTools::Util::CSTRING_CHUNK + 1).each do |len|
        expect(cstring("#{'a' * len}\0", 0)).to eq ['a' * len, len + 1]
      end
      long = 'a' * (ELFTools::Util::CSTRING_CHUNK * 10)
      expect(cstring("#{long}\0", 0)).to eq [long, long.bytesize + 1]
    end

    it 'reads the bytes a name is recorded as, whatever they mean' do
      # Names are read as bytes, so one that is not text reads back as it was.
      expect(cstring("\xff\xfe\0".b, 0).first).to eq "\xff\xfe".b
    end

    it 'answers with nothing where no null-byte follows' do
      expect(cstring('abc', 0).first).to be nil
      expect(cstring("abc\0", 4).first).to be nil
      expect(cstring("abc\0", 99).first).to be nil
    end
  end

  describe 'to_constant' do
    it 'answers for a name however it is spelled' do
      dt = ELFTools::Constants::DT
      [:symtab, 'symtab', :SYMTAB, 'DT_SYMTAB', :dt_symtab].each do |val|
        expect(ELFTools::Util.to_constant(dt, val)).to eq ELFTools::Constants::DT_SYMTAB
      end
      # Whichever way the constant spells it, some of them keeping the case
      # the ABI wrote them in.
      expect(ELFTools::Util.to_constant(ELFTools::Constants::SHT, :gnu_verneed))
        .to eq ELFTools::Constants::SHT::SHT_GNU_verneed
    end

    it 'answers for a value the module names' do
      expect(ELFTools::Util.to_constant(ELFTools::Constants::DT, 6)).to eq 6
      expect { ELFTools::Util.to_constant(ELFTools::Constants::DT, 1337) }
        .to raise_error(ArgumentError, 'No constants in Constants::DT is 1337')
      expect { ELFTools::Util.to_constant(ELFTools::Constants::DT, :xx) }
        .to raise_error(ArgumentError, 'No constants in Constants::DT named "DT_XX"')
    end

    it 'leaves a constant waiting to be autoloaded alone' do
      # EM records the names of the machines in a constant of its own, loaded
      # only once one is asked for. Reading the constants to answer for one
      # must not be what asks for them.
      loaded = ->(pid) { system(RbConfig.ruby, '-Ilib', '-relftools', '-e', pid, out: File::NULL) }
      expect(loaded.call(<<~RUBY)).to be true
        ELFTools::Util.to_constant(ELFTools::Constants::EM, 62)
        ELFTools::Util.to_constant(ELFTools::Constants::EM, :x86_64)
        exit($LOADED_FEATURES.none? { |f| f.include?('machine_names') })
      RUBY
    end
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
