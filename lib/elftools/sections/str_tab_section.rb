# frozen_string_literal: true

require 'elftools/sections/section'
require 'elftools/util'

module ELFTools
  module Sections
    # Class of string table section.
    # Usually for section .strtab and .dynstr,
    # which record names.
    class StrTabSection < Section
      # Return the section or symbol name.
      # @param [Integer] offset
      #   Usually from +shdr.sh_name+ or +sym.st_name+.
      # @return [String] The name without null bytes.
      def name_at(offset)
        return @data[offset...@data.index("\0", offset)] if @data
        Util.cstring(stream, header.sh_offset + offset)
      end

      def find_or_insert(name)
        return 0 if name.empty?
        ind = self.data.index("#{name}\0")
        if ind.nil?
          ind = self.data.size
          self.data += "#{name}\0"
        end
        ind
      end
    end
  end
end
