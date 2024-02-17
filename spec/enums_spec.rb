# frozen_string_literal: true

require 'elftools/enums'

class Numbers < Enum
  enum_attr :first, 1
  enum_attr :second, 2
  enum_attr :third, 3
end

describe Enum do
  it 'constructs' do
    expect(Numbers::FIRST).to eq 1
    expect(Numbers[1]).to eq 1
    expect(Numbers.SECOND).to eq 2
    expect(Numbers[:third]).to eq 3
    expect(Numbers.new('third')).to eq 3
    expect { Numbers[:fourth] }.to raise_error(ArgumentError)
    expect { Numbers.new('fifth') }.to raise_error(ArgumentError)
    expect { Numbers.new(6) }.to raise_error(ArgumentError)
    expect { Numbers[7] }.to raise_error(ArgumentError)
  end

  it 'compares' do
    expect(Numbers::FIRST).to eq Numbers::FIRST
    expect(Numbers::FIRST).not_to eq 2
    expect(Numbers.SECOND).to eq 2
    expect(Numbers[:third]).to eq 'third'
    expect(Numbers[:third]).not_to eq 'first'
    expect(Numbers.new('third')).to eq :third
  end
end
