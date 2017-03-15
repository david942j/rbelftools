require 'elftools/sections/section'

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
        stream.pos = header.sh_offset + offset
        # read until "\x00"
        ret = ''
        loop do
          c = stream.read(1)
          return nil if c.nil? # reach EOF
          break if c == "\x00"
          ret += c
        end
        ret
      end
    end
  end
end
