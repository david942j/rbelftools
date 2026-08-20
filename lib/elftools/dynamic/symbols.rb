# frozen_string_literal: true

require 'elftools/dynamic/hash_table'
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
        @num_symbols ||= (hash_tables.map(&:num_symbols) + [count_from_relocations]).compact.max || 0
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
      def each_symbol(&block)
        return enum_for(:each_symbol) unless block_given?

        Array.new(num_symbols) { |i| symbol_at(i).tap(&block) }
      end

      # The name this used to go by, kept so that it keeps working.
      alias each_symbols each_symbol

      # The symbols the tags point at, which is where a file that has been
      # stripped of its sections still records them.
      #
      # As many of them as {#num_symbols} reaches.
      # @return [Array<ELFTools::Sections::Symbol>] The symbols.
      # @example
      #   elf.dynamic.symbols.map(&:name)
      #   #=> ['', 'puts', '__stack_chk_fail', 'printf', '__libc_start_main']
      def symbols
        each_symbol.to_a
      end

      # Get symbol by its name.
      #
      # The hash tables answer first, which is the lookup the loader itself
      # performs and takes no scanning. They do not index every symbol, and a
      # file need not record one at all, so a name they do not lead to is
      # searched for among the symbols {#symbols} reaches.
      # @param [String] name The name of symbol.
      # @return [ELFTools::Sections::Symbol, nil] The desired symbol.
      # @example
      #   elf.dynamic.symbol_by_name('__libc_start_main').type_name
      #   #=> 'STT_FUNC'
      def symbol_by_name(name)
        # Lazily, so that a table is only read when the ones before it have
        # not led anywhere.
        index = hash_tables.lazy.filter_map { |table| table.index_of(name) { |i| symbol_at(i).name == name } }.first
        return symbol_at(index) if index

        each_symbol.find { |symbol| symbol.name == name }
      end

      private

      # The tables the file records the names it exports in, of whichever kinds
      # it records.
      # @return [Array<ELFTools::Dynamic::HashTable>] The tables.
      def hash_tables
        @hash_tables ||= { hash: HashTable::SysV, gnu_hash: HashTable::Gnu }.filter_map do |type, klass|
          tag = tag_by_type(type)
          klass.new(stream, offset_of(tag), elf_class: header.elf_class, endian:) if tag
        end
      end

      # How far the relocations reach, i.e. the highest index they name plus one.
      # They only ever name the symbols something in the file refers to.
      # @return [Integer, nil] The number, +nil+ if none names a symbol.
      def count_from_relocations
        highest = relocations.map(&:symbol_index).max
        highest && highest + 1
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
