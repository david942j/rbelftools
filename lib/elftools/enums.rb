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

    define_singleton_method(name.upcase.to_sym) { instance }
    const_set(name.upcase.to_sym, instance) if name.match?(/^[[:alpha:]]/)
  end

  class << self
    attr_reader :values

    def val(value)
      key = if value.is_a? self.class
              value.to_i
            elsif values.keys.include?(value)
              value
            else
              values.key(value.to_s)
            end
      raise ArgumentError, "Unknown enum #{value}" unless key

      key
    end

    def [](value)
      @instances[val(value)]
    end
  end

  # Initialize enum with value or name
  # @param [Integer, Symbol] n Value or name.
  # @return [Enum]
  #   Throws ArgumentError if enum name or value is invalid.
  def initialize(value = 0)
    @value = self.class.val(value)
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
    @value == self.class.val(other)
  end
end
