# frozen_string_literal: true

require 'elftools/constants'
require 'elftools/structs'

module ELFTools
  module Dynamic
    # The versions a file binds its symbols to.
    #
    # Two tables record them, the versions the file needs of the files it is
    # loaded with and the versions it defines for what it exports, and a symbol
    # names one of either by the same index.
    #
    # @note
    #   This module is included by {ELFTools::Dynamic} and reads through the
    #   methods there, so it cannot be included on its own.
    module Versions
      # The versions this file needs of the files it is loaded with.
      # @return [Array<ELFTools::Dynamic::Versions::Requirement>]
      #   The requirements, in the order the table records them.
      # @example
      #   elf.dynamic.version_requirements.map { |need| [need.file, need.versions.map(&:name)] }
      #   #=> [['libc.so.6', ['GLIBC_2.4', 'GLIBC_2.2.5']]]
      def version_requirements
        @version_requirements ||= read_requirements
      end

      # The versions this file defines for what it exports.
      #
      # The first of them is the file itself rather than a version of it, which
      # {Definition#base?} tells apart.
      # @return [Array<ELFTools::Dynamic::Versions::Definition>]
      #   The definitions, in the order the table records them.
      # @example
      #   elf.dynamic.version_definitions.map(&:name).first(3)
      #   #=> ['libc.so.6', 'GLIBC_2.2.5', 'GLIBC_2.2.6']
      def version_definitions
        @version_definitions ||= read_definitions
      end

      private

      # The version the +n+-th symbol binds to.
      # @param [Integer] n The symbol index.
      # @return [ELFTools::Dynamic::Versions::Version, nil]
      #   The version, +nil+ if the file records none, or if the symbol is one
      #   of the file's own or of no version at all.
      def version_at(n)
        recorded = versym_at(n)
        return if recorded.nil?

        index = recorded & ~Constants::VER_NDX_HIDDEN
        return if index <= Constants::VER_NDX_GLOBAL

        name = versions_by_index[index]
        Version.new(name, index, hidden: !(recorded & Constants::VER_NDX_HIDDEN).zero?) if name
      end

      # What the +n+-th symbol records as its version.
      # @return [Integer, nil] The index, +nil+ if the file records none.
      def versym_at(n)
        @versym_offset ||= begin
          tag = tag_by_type(:versym)
          tag && offset_of(tag)
        end
        return if @versym_offset.nil?

        stream.pos = @versym_offset + (n * 2)
        stream.read(2).to_s.unpack1(endian == :big ? 'S>' : 'S<')
      end

      # The name each index names, of either table.
      # @return [Hash{Integer => String}] The names.
      def versions_by_index
        @versions_by_index ||=
          (version_requirements.flat_map(&:versions) + version_definitions).to_h { |v| [v.index, v.name] }
      end

      # Reads the table +DT_VERNEED+ points at.
      # @return [Array<ELFTools::Dynamic::Versions::Requirement>] The requirements.
      def read_requirements
        each_entry(:verneed, :verneednum, Structs::ELF_Verneed, :vn_next) do |need, at|
          versions = read_chain(at + need.vn_aux.to_i, need.vn_cnt.to_i, Structs::ELF_Vernaux, :vna_next) do |aux|
            Version.new(string_table.name_at(aux.vna_name.to_i), aux.vna_other.to_i)
          end
          Requirement.new(string_table.name_at(need.vn_file.to_i), versions)
        end
      end

      # Reads the table +DT_VERDEF+ points at.
      # @return [Array<ELFTools::Dynamic::Versions::Definition>] The definitions.
      def read_definitions
        each_entry(:verdef, :verdefnum, Structs::ELF_Verdef, :vd_next) do |defn, at|
          names = read_chain(at + defn.vd_aux.to_i, defn.vd_cnt.to_i, Structs::ELF_Verdaux, :vda_next) do |aux|
            string_table.name_at(aux.vda_name.to_i)
          end
          # The first name is the version's own, the rest are what it descends from.
          Definition.new(names.first, defn.vd_ndx.to_i, names.drop(1),
                         base: !(defn.vd_flags.to_i & Constants::VER_FLG_BASE).zero?)
        end
      end

      # Reads the entries of a table the tags point at, as many as a tag counts.
      # @return [Array] What the block makes of each entry.
      def each_entry(address, count, klass, following)
        tag = tag_by_type(address)
        return [] if tag.nil?

        at = offset_of(tag)
        Array.new(tag_by_type(count).header.d_val.to_i) do
          entry = read_struct(klass, at)
          yield(entry, at).tap { at += entry.send(following).to_i }
        end
      end

      # Reads a chain of entries, each pointing at the one after it.
      # @return [Array] What the block makes of each entry.
      def read_chain(at, count, klass, following)
        Array.new(count) do
          entry = read_struct(klass, at)
          yield(entry).tap { at += entry.send(following).to_i }
        end
      end

      # A version a file needs or defines.
      class Version
        attr_reader :name # @return [String] The name, +GLIBC_2.2.5+ for instance.
        attr_reader :index # @return [Integer] The index the symbols name it with.

        # Instantiate a {ELFTools::Dynamic::Versions::Version} object.
        # @param [String] name The name.
        # @param [Integer] index The index.
        # @param [Boolean] hidden Whether a symbol binds to it as a version that is not the default.
        def initialize(name, index, hidden: false)
          @name = name
          @index = index
          @hidden = hidden
        end

        # Whether the symbol binding to this version binds to something other
        # than the default, which is what more than one version of a name means.
        # @return [Boolean] The answer.
        def hidden?
          @hidden
        end
      end

      # The versions a file needs of one of the files it is loaded with.
      class Requirement
        attr_reader :file # @return [String] The name of the file, +libc.so.6+ for instance.
        attr_reader :versions # @return [Array<ELFTools::Dynamic::Versions::Version>] The versions needed of it.

        # Instantiate a {ELFTools::Dynamic::Versions::Requirement} object.
        # @param [String] file The name of the file.
        # @param [Array<ELFTools::Dynamic::Versions::Version>] versions The versions.
        def initialize(file, versions)
          @file = file
          @versions = versions
        end
      end

      # A version a file defines for what it exports.
      class Definition
        attr_reader :name # @return [String] The name.
        attr_reader :index # @return [Integer] The index the symbols name it with.
        attr_reader :parents # @return [Array<String>] The names of the versions it descends from.

        # Instantiate a {ELFTools::Dynamic::Versions::Definition} object.
        # @param [String] name The name.
        # @param [Integer] index The index.
        # @param [Array<String>] parents The names it descends from.
        # @param [Boolean] base Whether it names the file rather than a version of it.
        def initialize(name, index, parents, base: false)
          @name = name
          @index = index
          @parents = parents
          @base = base
        end

        # Whether this names the file itself rather than a version of it, which
        # the first definition of a file does.
        # @return [Boolean] The answer.
        def base?
          @base
        end
      end
    end
  end
end
