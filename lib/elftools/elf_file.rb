require 'elftools/exceptions'
require 'elftools/structures'

module ELFTools
  # The main class for using elftools.
  class ELFFile
    MAGIC_HEADER = "\x7fELF".freeze
    attr_reader :stream # @return [File] The +File+ object.
    attr_reader :elf_class # @return [Integer] 32 or 64.
    attr_reader :endian # @return [Symbol] +:little+ or +:big+.

    # Instantiate a {ELFFile} object.
    #
    # @param [File] stream
    #   The +File+ object to be fetch information from.
    # @example
    #   ELFFile.new(File.open('/bin/cat'))
    #   #=> <ELFFile: >
    def initialize(stream)
      @stream = stream
      identify # fetch the most basic information
      stream.pos = 0
    end

    # Return thr file header.
    #
    # Lazy loading.
    # @retrn [ELFTools::ELF_Ehdr]
    def header
      return @header if @header
      stream.pos = 0
      @header = ELF_Ehdr.new(endian: endian).read(stream)
    end

    private

    def identify
      stream.pos = 0
      magic = stream.read(4)
      raise ELFError, "Invalid magic number #{magic.inspect}" unless magic == MAGIC_HEADER
      ei_class = stream.read(1).ord
      @elf_class = {
        1 => 32,
        2 => 64
      }[ei_class]
      raise ELFError, format('Invalid EI_CLASS "\x%02x"', ei_class) if elf_class.nil?
      ei_data = stream.read(1).ord
      @endian = {
        1 => :little,
        2 => :big
      }[ei_data]
      raise ELFError, format('Invalid EI_DATA "\x%02x"', ei_data) if endian.nil?
    end
  end
end
