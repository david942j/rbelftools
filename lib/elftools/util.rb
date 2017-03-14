module ELFTools
  # Define some util methods.
  module Util
    # Class methods.
    module ClassMethods
      # Round up the number to be mulitple of
      # +2**bit+.
      def align(num, bit)
        n = 2**bit
        return num if (num % n).zero?
        (num + n) & ~(n - 1)
      end
    end
    extend ClassMethods
  end
end
