module ELFTools
  # Base class of sections.
  class Section
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

    # get name of this section.
    def name
      @name = @name.call(header) if @name.respond_to?(:call)
      @name
    end
  end
end
