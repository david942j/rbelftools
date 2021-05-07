# frozen_string_literal: true

# copyright https://stackoverflow.com/questions/75759/how-to-implement-enums-in-ruby
#
class Enum
  def self.enum_attr(name, num)
    name = name.to_s

    @values ||= {}
    @values[num] = name

    define_method("#{name}?") do
      @value == num
    end

    instance = new(num)

    @instances ||= {}
    @instances[num] = instance
    @instances[name] = instance
    @instances[name.to_s.upcase] = instance

    define_singleton_method(name.upcase.to_sym) { instance }
    const_set(name.upcase.to_sym, instance) if name.match?(/^[[:alpha:]]/)
  end

  class << self
    attr_reader :values

    def [](value)
      value = value.to_i if value.is_a? self.class
      key = value.is_a?(Numeric) ? value : value.to_s.upcase
      @instances[key]
    end
  end

  # Initialize enum with value or name
  # @param [Integer, Symbol] n Value or name.
  # @return [Enum]
  #   Throws ArgumentError if enum name or value is invalid.
  def initialize(value = 0)
    @value =
      if value.is_a? self.class
        value.to_i
      elsif self.class.values.keys.include?(value)
        value
      else
        self.class.values.key(value.to_s.downcase)
      end
    raise ArgumentError, "Unknown enum #{value}" unless @value
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
    to_i == self.class[other].to_i
  end
end
