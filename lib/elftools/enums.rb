# copyright https://stackoverflow.com/questions/75759/how-to-implement-enums-in-ruby
#
class Enum
  private

  def self.enum_attr(name, num)
    name = name.to_s

    define_method(name + '?') do
      if self.class.exclusive?
        @attrs == num
      else
        @attrs & num != 0
      end
    end

    define_method(name + '=') do |set|
      if set
        @attrs |= num
      else
        @attrs &= ~num
      end
    end

    self.define_singleton_method(name.upcase.to_sym) do
      self.new(num)
    end

    @values ||= {}
    @values[num] = name
  end

  def self.exclusive(enabled)
    @exclusive = enabled
  end

  public
  def self.exclusive?
    @exclusive
  end

  def self.values
    @values
  end

  def initialize(attrs = 0)
    @attrs = self.class.values.key(attrs) || attrs
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
