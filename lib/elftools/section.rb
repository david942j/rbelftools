require 'elftools/constants'
module ELFTools
  # Base class of sections.
  class Section
    # Class methods.
    class << self
      # Use different class according to +header.sh_type+.
      def create(header, *args)
        klass = case header.sh_type
                when Constants::SHT_NULL then NullSection
                else Section
                end
        klass.new(header, *args)
      end
    end
    attr_reader :header # @return [ELFTools::ELF_Shdr] Section header.
    attr_reader :stream # @return [File] Streaming object.

    # Instantiate a {Section} object.
    # @param [ELFTools::ELF_Shdr] header
    #   The section header object.
    # @param [File] stream
    #   The streaming object for further dump.
    # @param [String, Proc] name
    #   The name of this section.
    #   If +Proc+ if given, it will call at the first
    #   time access +#name+.
    def initialize(header, stream, name)
      @header = header
      @stream = stream
      @name = name
    end

    # Get name of this section.
    # @return [String] The name.
    def name
      @name = @name.call(header) if @name.respond_to?(:call)
      @name
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

  # Class of null section.
  # Null section is for specific the end
  # of linked list(+sh_link+) between sections.
  class NullSection < Section
    def null?
      true
    end
  end
end
