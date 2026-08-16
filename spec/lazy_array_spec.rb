# frozen_string_literal: true

require 'elftools/lazy_array'

describe ELFTools::LazyArray do
  before do
    @loaded = []
    @arr = ELFTools::LazyArray.new(3) do |i|
      @loaded << i
      i * i
    end
  end

  it 'loads on demand' do
    expect(@arr.size).to be 3
    expect(@arr.length).to be 3
    expect(@loaded).to eq []

    expect(@arr[1]).to be 1
    expect(@loaded).to eq [1]

    # Already loaded elements are not calculated again.
    expect(@arr[1]).to be 1
    expect(@loaded).to eq [1]
  end

  it 'out of bound' do
    expect(@arr[3]).to be nil
    # Negative index is not supported.
    expect(@arr[-1]).to be nil
    expect(@loaded).to eq []
  end

  it 'behaves like an array' do
    expect(@arr.to_a).to eq [0, 1, 4]
    expect(@arr.map { |v| v + 1 }).to eq [1, 2, 5]
    expect(@arr.last).to be 4
    expect(@arr.include?(4)).to be true
    expect(@arr.inspect).to eq '[0, 1, 4]'
    # Each element is loaded exactly once.
    expect(@loaded.sort).to eq [0, 1, 2]
  end

  it 'responds to array methods without loading' do
    expect(@arr.respond_to?(:map)).to be true
    expect(@arr.respond_to?(:no_such_method)).to be false
    expect(@loaded).to eq []
  end
end
