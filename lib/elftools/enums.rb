# frozen_string_literal: true

# copyright https://stackoverflow.com/questions/75759/how-to-implement-enums-in-ruby
#
class Enum
  def self.enum_attr(name, num)
    name = name.to_s

    define_method("#{name}?") do
      if self.class.exclusive?
        @attrs == num
      else
        @attrs & num != 0
      end
    end

    define_method("#{name}=") do |set|
      if set
        @attrs |= num
      else
        @attrs &= ~num
      end
    end

    define_singleton_method(name.upcase.to_sym) do
      new(num)
    end

    @values ||= {}
    @values[num] = name
  end

  def self.exclusive(enabled)
    @exclusive = enabled
  end

  def self.exclusive?
    @exclusive
  end

  class << self
    attr_reader :values
  end

  def initialize(attrs = 0)
    @attrs =
      if self.class.values.keys.include?(attrs)
        attrs
      else
        self.class.values.index(attrs.to_s.downcase)
      end
    throw ArgumentError.new("Uknown enum #{attrs}") unless @attrs
  end

  def to_i
    @attrs
  end

  def to_s
    self.class.values[@attrs] || @attrs.to_s
  end

  def inspect
    v = self.class.values[@attrs]
    v ? "#{self.class.name}.#{v.upcase}" : @attrs
  end

  def ==(other)
    to_i == other.to_i
  end
end
