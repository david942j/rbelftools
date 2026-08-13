# frozen_string_literal: true

require 'elftools/constants'
require 'elftools/relocation'
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
      # @return [ELFTools::Relocation, nil]
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
      # @yieldparam [ELFTools::Relocation] rel A relocation object.
      # @yieldreturn [void]
      # @return [Enumerator<ELFTools::Relocation>, Array<ELFTools::Relocation>]
      #   If block is not given, an enumerator will be returned.
      #   Otherwise, the whole relocations will be returned.
      def each_relocations(&block)
        return enum_for(:each_relocations) unless block_given?

        Array.new(num_relocations) do |i|
          relocation_at(i).tap(&block)
        end
      end

      # Simply use {#relocations} to get all relocations.
      # @return [Array<ELFTools::Relocation>]
      #   Whole relocations.
      def relocations
        each_relocations.to_a
      end

      private

      def create_relocation(n)
        stream.pos = header.sh_offset + n * header.sh_entsize
        klass = rela? ? Structs::ELF_Rela : Structs::ELF_Rel
        rel = klass.new(endian: header.class.self_endian, offset: stream.pos)
        rel.elf_class = header.elf_class
        rel.read(stream)
        Relocation.new(rel, stream)
      end
    end
  end
end
