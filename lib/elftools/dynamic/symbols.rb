# frozen_string_literal: true

require 'elftools/exceptions'
require 'elftools/sections/symbol'
require 'elftools/structs'

module ELFTools
  module Dynamic
    # The symbols a file is loaded by, which the tags point at.
    #
    # @note
    #   This module is included by {ELFTools::Dynamic} and reads through the
    #   methods there, so it cannot be included on its own.
    module Symbols
      # Get the +n+-th symbol.
      #
      # Symbols are lazy loaded.
      # @note
      #   We cannot do bound checking of +n+ here, because nothing records how
      #   many symbols there are. {#num_symbols} is a lower bound rather than a
      #   bound, so checking against it would hide symbols this method reads
      #   correctly.
      # @param [Integer] n The index.
      # @return [ELFTools::Sections::Symbol] The desired symbol.
      # @raise [ELFTools::ELFError]
      #   If +DT_SYMTAB+ is absent, or its address is not in any loadable segment.
      def symbol_at(n)
        return if n.negative?

        @symbol_at_map ||= {}
        @symbol_at_map[n] ||= begin
          klass = Structs::ELF_sym[header.elf_class]
          # An entry takes what its structure takes, which is also what
          # DT_SYMENT records and what a file has no way of disagreeing with.
          sym = read_struct(klass, sym_offset + (n * struct(klass).num_bytes))
          Sections::Symbol.new(sym, stream, symstr: method(:string_table), machine: @machine)
        end
      end

      # How many symbols the tags reach.
      #
      # Nothing a file is loaded by records how large its symbol table is. The
      # loader never enumerates it: it looks a name up through a hash table and
      # jumps straight to an index, so where the table ends is none of its
      # business. Two things bound it instead, the hash table that indexes the
      # names a file exports and the relocations that name a symbol by index,
      # and the answer is how far the further of the two reaches. Only +DT_HASH+
      # records the number outright.
      #
      # This is therefore a lower bound. A symbol that is neither indexed by the
      # hash table nor named by a relocation is invisible to both, and is
      # missing from the count. {#symbol_at} is exact for any index.
      # @return [Integer] The number.
      # @example
      #   elf.dynamic.num_symbols
      #   #=> 9
      def num_symbols
        @num_symbols ||= [count_from_hash, count_from_gnu_hash, count_from_relocations].compact.max || 0
      end

      # Iterate all symbols.
      #
      # Symbols are lazy loaded, so {#symbol_by_name} only creates the symbols
      # it has to look at.
      # @yieldparam [ELFTools::Sections::Symbol] symbol A symbol object.
      # @yieldreturn [void]
      # @return [Enumerator<ELFTools::Sections::Symbol>, Array<ELFTools::Sections::Symbol>]
      #   If block is not given, an enumerator will be returned.
      #   Otherwise, return array of symbols.
      def each_symbols(&block)
        return enum_for(:each_symbols) unless block_given?

        Array.new(num_symbols) { |i| symbol_at(i).tap(&block) }
      end

      # The symbols the tags point at, which is where a file that has been
      # stripped of its sections still records them.
      #
      # As many of them as {#num_symbols} reaches.
      # @return [Array<ELFTools::Sections::Symbol>] The symbols.
      # @example
      #   elf.dynamic.symbols.map(&:name)
      #   #=> ['', 'puts', '__stack_chk_fail', 'printf', '__libc_start_main']
      def symbols
        each_symbols.to_a
      end

      # Get symbol by its name.
      #
      # Only the symbols {#symbols} reaches are searched.
      # @param [String] name The name of symbol.
      # @return [ELFTools::Sections::Symbol, nil] The desired symbol.
      def symbol_by_name(name)
        each_symbols.find { |symbol| symbol.name == name }
      end

      private

      # How many symbols +DT_HASH+ records, which is exact: a chain of the table
      # belongs to every symbol, whether the table indexes it or not.
      # @return [Integer, nil] The number, +nil+ if the tag is absent.
      def count_from_hash
        tag = tag_by_type(:hash)
        return if tag.nil?

        read_struct(Structs::ELF_Hash, offset_of(tag)).nchain.to_i
      end

      # How far +DT_GNU_HASH+ reaches, i.e. the highest index it indexes plus
      # one. It only ever indexes the defined symbols a file exports under a
      # name, and the symbols before +symndx+ are by construction not among
      # them.
      # @return [Integer, nil] The number, +nil+ if the tag is absent.
      def count_from_gnu_hash
        tag = tag_by_type(:gnu_hash)
        return if tag.nil?

        base = offset_of(tag)
        head = read_struct(Structs::ELF_GnuHash, base)
        buckets = base + head.num_bytes + (head.maskwords.to_i * header.elf_class / 8)
        last = Array.new(head.nbuckets.to_i) { |i| read_word(buckets + (i * 4)) }.max || 0
        return head.symndx.to_i if last < head.symndx.to_i

        chain = buckets + (head.nbuckets.to_i * 4)
        # The chain of a bucket runs on until an entry has its lowest bit set.
        n = last - head.symndx.to_i
        n += 1 while read_word(chain + (n * 4)).even?
        head.symndx.to_i + n + 1
      end

      # How far the relocations reach, i.e. the highest index they name plus one.
      # They only ever name the symbols something in the file refers to.
      # @return [Integer, nil] The number, +nil+ if none names a symbol.
      def count_from_relocations
        highest = relocations.map(&:symbol_index).max
        highest && highest + 1
      end

      # Reads a word, the unit a hash table lays its entries out in.
      # @param [Integer] offset The file offset.
      # @return [Integer] The word.
      def read_word(offset)
        stream.pos = offset
        stream.read(4).unpack1(endian == :big ? 'N' : 'V')
      end

      # Get the +DT_SYMTAB+'s +d_val+ offset related to file.
      # @return [Integer] The file offset.
      # @raise [ELFTools::ELFError]
      #   If +DT_SYMTAB+ is absent, or its address is not in any loadable segment.
      def sym_offset
        @sym_offset ||= begin
          symtab = tag_by_type(:symtab)
          raise ELFError, 'DT_SYMTAB not found' if symtab.nil?

          offset_of(symtab)
        end
      end
    end
  end
end
