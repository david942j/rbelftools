require 'elftools/sections/section'

module ELFTools
  module Sections
    # Class of null section.
    # Null section is for specific the end
    # of linked list(+sh_link+) between sections.
    class NullSection < Section
      def null?
        true
      end
    end
  end
end
