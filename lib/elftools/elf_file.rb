require 'elftools/constants'
require 'elftools/exceptions'
require 'elftools/lazy_array'
require 'elftools/sections/sections'
require 'elftools/segments/segments'
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

    # Return the file header.
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

    # Return the BuildID of current file.
    # @return [String, NilClass]
    #   BuildID in hex form will be returned.
    #   +nil+ is returned if the .note.gnu.build-id section
    #   is not found.
    # @example
    #   elf.build_id
    #   #=> '73ab62cb7bc9959ce053c2b711322158708cdc07'
    def build_id
      section = section_by_name('.note.gnu.build-id')
      return nil if section.nil?
      note = section.notes.first
      return nil if note.nil?
      note.desc.unpack('H*').first
    end

    # Get Machine architecture.
    #
    # Mappings of architecture can be found
    # in {ELFTools::Constants::EM#mapping}.
    # @return [String]
    #   Name of architecture.
    # @example
    #   elf.machine
    #   #=> 'Advanced Micro Devices X86-64'
    def machine
      ELFTools::Constants::EM.mapping(header.e_machine)
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
    # @return [ELFTools::Sections::Section, NilClass] The target section.
    # @example
    #   elf.section_by_name('.note.gnu.build-id')
    #   #=> #<ELFTools::Sections::Section:0x005647b1282428>
    #   elf.section_by_name('')
    #   #=> #<ELFTools::Sections::NullSection:0x005647b11da110>
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
    # @return [ Array<ELFTools::Sections::Section>]
    #   The whole sections will be returned.
    def each_sections
      Array.new(num_sections) do |i|
        sec = section_at(i)
        block_given? ? yield(sec) : sec
      end
    end

    # Simply use {#sections} without giving block to get all sections.
    alias sections each_sections

    # Acquire the +n+-th section, 0-based.
    #
    # Sections are lazy loaded.
    # @param [Integer] n The index.
    # @return [ELFTools::Sections::Section, NilClass]
    #   The target section.
    #   If +n+ is out of bound, +nil+ is returned.
    def section_at(n)
      @sections ||= LazyArray.new(num_sections, &method(:create_section))
      @sections[n]
    end

    # Get the StringTable section.
    # @return [ELFTools::Sections::Section] The desired section.
    def strtab_section
      section_at(header.e_shstrndx)
    end

    #========= method about segments

    # Number of segments in this file.
    # @return [Integer] The desited number.
    def num_segments
      header.e_phnum
    end

    # Iterate all segments.
    #
    # All segments are lazy loading, the segment
    # only create whenever accessing it.
    # This method is useful for {#segment_by_type}
    # since not all segments need to be created.
    # @param [Block] block
    #   Just like +Array#each+, you can give a block.
    # @return [Array<ELFTools::Segments::Segment>]
    #   Whole segments will be returned.
    def each_segments
      Array.new(num_segments) do |i|
        seg = segment_at(i)
        block_given? ? yield(seg) : seg
      end
    end

    # Simply use {#segments} without giving block to get all segments.
    alias segments each_segments

    # Get the first segment with +p_type=type+.
    # The available types are listed in {ELFTools::Constants},
    # starts with +PT_+.
    #
    # Notice: this method will return the first segment found,
    # to found all segments with specific type you can use {#segments_by_type}.
    # @param [Integer, Symbol, String] type
    #   See examples for clear usage.
    # @return [ELFTools::Segments::Segment] The target segment.
    # @example
    #   # type as an integer
    #   elf.segment_by_type(ELFTools::Constants::PT_NOTE)
    #   #=>  #<ELFTools::Segments::NoteSegment:0x005629dda1e4f8>
    #
    #   elf.segment_by_type(4) # PT_NOTE
    #   #=>  #<ELFTools::Segments::NoteSegment:0x005629dda1e4f8>
    #
    #   # type as a symbol
    #   elf.segment_by_type(:PT_NOTE)
    #   #=>  #<ELFTools::Segments::NoteSegment:0x005629dda1e4f8>
    #
    #   # you can do this
    #   elf.segment_by_type(:note) # will be transformed into `PT_NOTE`
    #   #=>  #<ELFTools::Segments::NoteSegment:0x005629dda1e4f8>
    #
    #   # type as a string
    #   elf.segment_by_type('PT_NOTE')
    #   #=>  #<ELFTools::Segments::NoteSegment:0x005629dda1e4f8>
    #
    #   # this is ok
    #   elf.segment_by_type('note') # will be tranformed into `PT_NOTE`
    #   #=>  #<ELFTools::Segments::NoteSegment:0x005629dda1e4f8>
    # @example
    #   elf.segment_by_type(1337)
    #   # ArgumentError: No PT type is "1337"
    #
    #   elf.segment_by_type('oao')
    #   # ArgumentError: No PT type named "PT_OAO"
    # @example
    #   elf.segment_by_type(0)
    #   #=> nil # no such segment exists
    def segment_by_type(type)
      type = Util.to_constant(Constants::PT, type, msg: 'PT type')
      each_segments do |segment|
        return segment if segment.header.p_type == type
      end
      nil
    end

    # Fetch all segments with specific type.
    # If you want to find only one segment,
    # use {#segment_by_type} instead.
    # @param [Integer, Symbol, String] type
    #   The type needed, same format as {#segment_by_type}.
    # @return [Array<ELFTools::Segments::Segment>] The target segments.
    def segments_by_type(type)
      type = Util.to_constant(Constants::PT, type, msg: 'PT type')
      segments.select { |segment| segment.header.p_type == type }
    end

    # Acquire the +n+-th segment, 0-based.
    #
    # Segments are lazy loaded.
    # @param [Integer] n The index.
    # @return [ELFTools::Segments::Segment, NilClass]
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
      Sections::Section.create(shdr, stream,
                               strtab: method(:strtab_section),
                               section_at: method(:section_at))
    end

    def create_segment(n)
      stream.pos = header.e_phoff + n * header.e_phentsize
      phdr = ELF_Phdr[elf_class].new(endian: endian)
      phdr.elf_class = elf_class
      Segments::Segment.create(phdr.read(stream), stream)
    end
  end
end
