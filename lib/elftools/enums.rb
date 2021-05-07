# frozen_string_literal: true

# copyright https://stackoverflow.com/questions/75759/how-to-implement-enums-in-ruby
#
class Enum
  def self.enum_attr(name, num)
    name = name.to_s

    define_method("#{name}?") do
      @value == num
    end

    define_singleton_method(name.upcase.to_sym) do
      new(num)
    end

    @values ||= {}
    @values[num] = name
  end

  class << self
    attr_reader :values
  end

  # Initialize enum with value or name
  # @param [Integer, Symbol] n Value or name.
  # @return [Enum]
  #   Throws ArgumentError if enum name or value is invalid.
  def initialize(value = 0)
    @value =
      if self.class.values.keys.include?(value)
        value
      else
        self.class.values.key(value.to_s.downcase)
      end
    raise ArgumentError.new("Unknown enum #{value}") unless @value
  end

  def to_i
    @value
  end

  def to_s
    self.class.values[@value] || @value.to_s
  end

  def inspect
    v = self.class.values[@value]
    v ? "#{self.class.name}.#{v.upcase}" : @value
  end

  def ==(other)
    to_i == other.to_i
  end
end
