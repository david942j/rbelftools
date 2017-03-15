module ELFTools
  # Define some util methods.
  module Util
    # Class methods.
    module ClassMethods
      # Round up the number to be mulitple of
      # +2**bit+.
      # @param [Integer] num Number to be rounded-up.
      # @param [Integer] bit How many bit to be aligned.
      # @example
      #   align(10, 1) #=> 10
      #   align(10, 2) #=> 12
      #   align(10, 3) #=> 16
      #   align(10, 4) #=> 16
      #   align(10, 5) #=> 32
      def align(num, bit)
        n = 2**bit
        return num if (num % n).zero?
        (num + n) & ~(n - 1)
      end

      # Fetch the correct value from module +mod+.
      #
      # See {ELFTools::ELFFile#segment_by_type} for how to
      # use this method.
      # @param [Module] mod The module defined constant numbers.
      # @param [Integer, Symbol, String] val
      #   Desired value.
      # @return [Integer]
      #   Rurrently this method should always return a value
      #   from {ELFTools::Constants}.
      def to_constant(mod, val, msg: 'constant')
        # if val is an integer, check if exists in mod
        if val.is_a?(Integer)
          return val if mod.constants.any? { |c| mod.const_get(c) == val }
          raise ArgumentError, "No #{msg} is \"#{val}\""
        end
        val = val.to_s.upcase
        prefix = mod.name.split('::')[-1]
        val = prefix + '_' + val unless val.start_with?(prefix)
        val = val.to_sym
        raise ArgumentError, "No #{msg} named \"#{val}\"" unless mod.const_defined?(val)
        mod.const_get(val)
      end
    end
    extend ClassMethods
  end
end
