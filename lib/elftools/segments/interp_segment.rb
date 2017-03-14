require 'elftools/segments/segment'

module ELFTools
  # For DT_INTERP segment, knows how to get path of
  # ELF interpreter.
  class InterpSegment < Segment
    def interp_name
      data[0..-2] # remove last null byte
    end
  end
end
