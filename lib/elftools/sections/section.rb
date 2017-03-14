require 'elftools/constants'
module ELFTools
  # Base class of sections.
  class Section
    # Class methods.
    class << self
      # Use different class according to +header.sh_type+.
      # @param [ELFTools::ELF_Shdr] header Section header.
      # @param [File] stream Streaming object.
      # @return [ELFTools::Section]
      #   Return object dependes on +header.sh_type+.
      def create(header, stream, *args)
        klass = case header.sh_type
                when Constants::SHT_NULL then NullSection
                when Constants::SHT_STRTAB then StrTabSection
                when Constants::SHT_NOTE then NoteSection
                when Constants::SHT_SYMTAB, Constants::SHT_DYNSYM then SymTabSection
                else Section
                end
        klass.new(header, stream, *args)
      end
    end
    attr_reader :header # @return [ELFTools::ELF_Shdr] Section header.
    attr_reader :stream # @return [File] Streaming object.

    # Instantiate a {Section} object.
    # @param [ELFTools::ELF_Shdr] header
    #   The section header object.
    # @param [File] stream
    #   The streaming object for further dump.
    # @param [ELFTools::StrTabSection, Proc] strtab
    #   The string table object. For fetching section names.
    #   If +Proc+ if given, it will call at the first
    #   time access +#name+.
    def initialize(header, stream, strtab: nil, **_kwagrs)
      @header = header
      @stream = stream
      @strtab = strtab
    end

    # Get name of this section.
    # @return [String] The name.
    def name
      @name ||= @strtab.call.name_at(header.sh_name)
    end

    # Fetch data of this section.
    # @return [String] Data.
    def data
      stream.pos = header.sh_offset
      stream.read(header.sh_size)
    end

    def null?
      false
    end
  end
end
