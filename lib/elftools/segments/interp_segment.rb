require 'elftools/segments/segment'

module ELFTools
  # For DT_INTERP segment, knows how to get path of
  # ELF interpreter.
  class InterpSegment < Segment
    # Get the path of interpreter.
    # @return [String] The interpreter name.
    # @example
    #   interp_name
    #   #=> /lib64/ld-linux-x86-64.so.2
    def interp_name
      data[0..-2] # remove last null byte
    end
  end
end
