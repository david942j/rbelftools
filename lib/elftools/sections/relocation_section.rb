require 'elftools/constants'
require 'elftools/sections/section'
require 'elftools/structs'

module ELFTools
  module Sections
    # Class of note section.
    # Note section records notes
    class RelocationSection < Section
      # Is this relocation a RELA or REL type.
      # @return [Boolean] If is RELA.
      def rela?
        header.sh_type == Constants::SHT_RELA
      end

      # Number of relocations in this section.
      # @return [Integer] The number.
      def num_relocations
        header.sh_size / header.sh_entsize
      end

      # Acquire the +n+-th relocation, 0-based.
      #
      # relocations are lazy loaded.
      # @param [Integer] n The index.
      # @return [ELFTools::Relocation, NilClass]
      #   The target relocation.
      #   If +n+ is out of bound, +nil+ is returned.
      def relocation_at(n)
        @relocations ||= LazyArray.new(num_relocations, &method(:create_relocation))
        @relocations[n]
      end

      # Iterate all relocations.
      #
      # All relocations are lazy loading, the relocation
      # only be created whenever accessing it.
      # @param [Block] block
      #   Just like +Array#each+, you can give a block.
      # @return [Array<ELFTools::relocation>]
      #   The whole relocations will be returned.
      def each_relocations
        Array.new(num_relocations) do |i|
          rel = relocation_at(i)
          block_given? ? yield(rel) : rel
        end
      end

      alias relocations each_relocations

      private

      def create_relocation(n)
        stream.pos = header.sh_offset + n * header.sh_entsize
        klass = rela? ? Structs::ELF_Rela : Structs::ELF_Rel
        rel = klass.new(endian: header.class.self_endian)
        rel.elf_class = header.elf_class
        rel.read(stream)
        Relocation.new(rel, stream)
      end
    end
  end

  # A relocation entry.
  #
  # Can be either a REL or RELA relocation.
  # XXX: move this to an independent file?
  class Relocation
    attr_reader :header # @return [ELFTools::Structs::ELF_Rel, ELFTools::Structs::ELF_Rela] Rel(a) header.
    attr_reader :stream # @return [File] Streaming object.

    # Instantiate a {Relocation} object.
    def initialize(header, stream)
      @header = header
      @stream = stream
    end

    # +r_info+ contains sym and type, use two methods
    # to access them easier.
    # @return [Integer] sym infor.
    def r_info_sym
      header.r_info >> mask_bit
    end

    # +r_info+ contains sym and type, use two methods
    # to access them easier.
    # @return [Integer] type infor.
    def r_info_type
      header.r_info & ((1 << mask_bit) - 1)
    end

    private

    def mask_bit
      header.elf_class == 32 ? 8 : 32
    end
  end
end
