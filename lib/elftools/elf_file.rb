require 'elftools/constants'
require 'elftools/exceptions'
require 'elftools/lazy_array'
require 'elftools/section'
require 'elftools/segment'
require 'elftools/structures'

module ELFTools
  # The main class for using elftools.
  class ELFFile
    attr_reader :stream # @return [File] The +File+ object.
    attr_reader :elf_class # @return [Integer] 32 or 64.
    attr_reader :endian # @return [Symbol] +:little+ or +:big+.

    # Instantiate a {ELFFile} object.
    #
    # @param [File] stream
    #   The +File+ object to be fetch information from.
    # @example
    #   ELFFile.new(File.open('/bin/cat'))
    #   #=> #<ELFTools::ELFFile:0x005647b1182ed8>
    def initialize(stream)
      @stream = stream
      identify # fetch the most basic information
    end

    # Return thr file header.
    #
    # Lazy loading.
    # @retrn [ELFTools::ELF_Ehdr] The header.
    def header
      return @header if @header
      stream.pos = 0
      @header = ELF_Ehdr.new(endian: endian)
      @header.elf_class = elf_class
      @header.read(stream)
    end

    #========= method about sections

    # Number of sections in this file.
    # @return [Integer] The desired number.
    # @example
    #   elf.num_sections
    #   #=> 29
    def num_sections
      header.e_shnum
    end

    # Acquire the section named as +name+.
    # @param [String] name The desired section name.
    # @return [ELFTools::Section, NilClass] The target section.
    # @example
    #   elf.section_by_name('.note.gnu.build-id')
    #   #=> #<ELFTools::Section:0x005647b1282428>
    #   elf.section_by_name('')
    #   #=> #<ELFTools::NullSection:0x005647b11da110>
    #   elf.section_by_name('no such section')
    #   #=> nil
    def section_by_name(name)
      @section_name_map ||= {}
      return @section_name_map[name] if @section_name_map[name]
      each_sections do |section|
        @section_name_map[section.name] = section
        return section if section.name == name
      end
      nil
    end

    # Iterate all sections.
    #
    # All sections are lazy loading, the section
    # only create whenever accessing it.
    # This method is useful for {#section_by_name}
    # since not all sections need to be created.
    # @param [Block] block
    #   Just like +Array#each+, you can give a block.
    # @return [void, Array<ELFTools::Section>]
    #   If no block is given, the whole sections will
    #   be returned.
    #   Otherwise, since sections are lazy loaded,
    #   the return value is not important.
    def each_sections
      if block_given?
        num_sections.times do |i|
          yield section_at(i)
        end
      else
        Array.new(num_sections) { |i| section_at(i) }
      end
    end

    # Simply use {#sections} without giving block to get all sections.
    alias sections each_sections

    # Acquire the +n+-th section, 0-based.
    #
    # Sections are lazy loaded.
    # @param [Integer] n The index.
    # @return [ELFTools::Section, NilClass]
    #   The target section.
    #   If +n+ is out of bound, +nil+ is returned.
    def section_at(n)
      @sections ||= LazyArray.new(num_sections, &method(:create_section))
      @sections[n]
    end

    # Get the StringTable section.
    # @return [ELFTools::Section] The desired section.
    def strtab_section
      section_at(header.e_shstrndx)
    end

    #========= method about segments

    # Number of segments in this file.
    # @return [Integer] The desited number.
    def num_segments
      header.e_phnum
    end

    # All segments.
    # @return [Array<ELFTools::Segment>] Array of segments.
    def segments
      # XXX: is here need lazy loading?
      Array.new(num_segments) { |i| segment_at(i) }
    end

    # Acquire the +n+-th segment, 0-based.
    #
    # Segments are lazy loaded.
    # @param [Integer] n The index.
    # @return [ELFTools:Segment, NilClass]
    #   The target segment.
    #   If +n+ is out of bound, +nil+ is returned.
    def segment_at(n)
      @segments ||= LazyArray.new(num_segments, &method(:create_segment))
      @segments[n]
    end

    private

    def identify
      stream.pos = 0
      magic = stream.read(4)
      raise ELFError, "Invalid magic number #{magic.inspect}" unless magic == Constants::ELFMAG
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

    def create_section(n)
      stream.pos = header.e_shoff + n * header.e_shentsize
      shdr = ELF_Shdr.new(endian: endian)
      shdr.elf_class = elf_class
      shdr.read(stream)
      Section.create(shdr, stream,
                     strtab: method(:strtab_section),
                     section_at: method(:section_at))
    end

    def create_segment(n)
      stream.pos = header.e_phoff + n * header.e_phentsize
      phdr = ELF_Phdr[elf_class].new(endian: endian).read(stream)
      Segment.new(phdr, stream)
    end
  end
end
