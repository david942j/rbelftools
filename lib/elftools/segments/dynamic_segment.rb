require 'elftools/segments/segment'
require 'elftools/dynamic'

module ELFTools
  module Segments
    # Class for dynamic table segment.
    #
    # This class knows how to get the list of dynamic tags.
    class DynamicSegment < Segment
      include Dynamic # rock!
      def tag_start
        header.p_offset
      end
    end
  end
end
