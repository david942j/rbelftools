# frozen_string_literal: true

require 'elftools/enums'

class Numbers < Enum
  enum_attr :first, 1
  enum_attr :second, 2
  enum_attr :third, 3
end

describe Enum do
  it 'constructs' do
    n = Numbers
    expect(n::FIRST).to eq 1
    expect(n.SECOND).to eq 2
    expect(n[:third]).to eq 3
    expect(n.new('third')).to eq 3
  end

  it 'compares' do
    n = Numbers
    expect(n::FIRST).to eq n::FIRST
    expect(n.SECOND).to eq 2
    expect(n[:third]).to eq 'third'
    expect(n.new('third')).to eq :third
  end
end
